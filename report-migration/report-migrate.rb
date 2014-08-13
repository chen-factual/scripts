require 'json'
require 'mongo'
require 'bson'
include Mongo

class ReportMigrate

  HOST_NAME = 'mongo1'
  HOST_PORT = 27017
  STITCH_DB = 'stitch'
  DEV_DB = 'stitch-cg'
  ALLOWED_REPORTS = []

  def initialize()
    server = MongoClient.new HOST_NAME, HOST_PORT
    @stitch = server[STITCH_DB]
    @stitch_reports = @stitch.collection 'reports'
    @dev = server[DEV_DB]
    @dev_reports = @dev.collection 'reports'
    warn 'initialization successful'
  end

  def copy_reports()
    new_reports = {}
    reports = @stitch_reports.find LIVE_FILTER
    warn "Found " + reports.count.to_s + " reports"
    reports.each do |report|
      if ALLOWED_REPORTS.include? report['report_name']
        # TODO: Whitelist reports
      end
      dev_report = create_dev_report(report)
      copy_report_data(report, dev_report)
    end
  end

  # Create report in dev db. If it already
  # exists then update the existing document
  def create_dev_report(report)
    run = report['run_name']
    view = report['view_id']
    query = dev_report_query(run, view)
    existing = @dev_reports.find_one(query)
    if existing.nil?
      insert_new_dev_report(report)
    else
      update_dev_report(query, report)
    end
    return @dev_reports.find_one(query)
  end

  def update_dev_report(query, report)
    sub_report = report['report_name']
    update_doc = {
      :$set => {
        "reports.#{sub_report}" => true
      }
    }
    if sub_report == 'data_quality_metrics_accuracy'
      code_ver = report['config']['dqm__code_sha']
      data_ver = report['config']['dqm__data_sha'] || report['config']['dqm_inputs_version']
      data = dev_report_data(report)
      dqmReports = []
      data.each_pair do |metal, metal_data|
        dqmReports << {
          :code_sha => code_ver,
          :dqm_inputs_version => data_ver,
          :metal => metal
        }
      end
      update_doc[:$push] = {
        :dqm_versions => {
          :$each => dqmReports
        }
      }
    end
    @dev_reports.update(query, update_doc)
  end

  def insert_new_dev_report(report)
    new_report = {
      :run_name => report['run_name'],
      :view_id => report['view_id'],
      :reports => {
        report['report_name'] => true
      }
    }
    if not (report['config'].nil? or report['config']['run_version'].nil?)
      new_report[:version] = report['config']['run_version']
    end
    @dev_reports.insert new_report
  end

  # Copy report data from old format to new format
  def copy_report_data(prod_report, report)
    sub = prod_report['report_name']
    ensure_report_data_col(@dev, report['view_id'], sub)
    data = dev_report_data(prod_report)
    begin
      store_dev_data(sub, report['_id'], data, prod_report)
    rescue Exception => e
      warn "Execption: " + e.message
      warn "Failed to store data: #{prod_report['run_name']} #{report['view_id']} #{sub} #{timestamp}"
      warn 'Failed to store data: ' + data.to_s
    end

  end

  def dev_report_data(prod_report)
    data = get_prod_data(prod_report['_id'], prod_report['view_id'], prod_report['report_name'])
    warn "report #{prod_report['_id']} #{prod_report['report_name']} num data rows " + data.count.to_s
    packed_data = pack_data(data)
    return packed_data
  end

  # REPORTS

  def get_dev_reports()
    reports = @dev_reports.find
    warn 'num dev reports ' + reports.count.to_s
    return reports
  end

  def get_prod_report(run, view_id, report)
    query = {
      :run_name => run,
      :view_id => view_id,
      :report_name => report
    }
    opts = {
      :sort => [['created_at', :descending ]],
      :limit => 1
    }
    return @stitch_reports.find(query, opts).next
  end

  # DATA

  def get_prod_data(id, view_id, report)
    col_name = prod_col_name(view_id, report)
    query = { :report_id => id }
    prod_data = @stitch[col_name].find query
    return prod_data
  end

  def store_dev_data(report_name, id, data, prod_report)
    timestamp = prod_report['created_at'] || prod_report['insert_time']
    col_name = dev_col_name(report_name)
    query = dev_report_data_query(id, timestamp)
    doc = {
      :report_id => id,
      :timestamp => timestamp
    }
    # For DQM report, add extra meta data
    if report_name == 'data_quality_metrics_accuracy'
      code_ver = prod_report['config']['dqm__code_sha']
      data_ver = prod_report['config']['dqm__data_sha'] || prod_report['config']['dqm_inputs_version']
      thresh = prod_report['config']['resolve_threshold']
      data.each_pair do |metal, metal_data|
        doc[:config] = {
          :code_sha => code_ver,
          :dqm_inputs_version => data_ver,
          :resolve_threshold => thresh,
          :metal => metal
        }
        doc[:data] = metal_data
        query[:config][:metal] = metal
        store_dev_data_doc(col_name, query, doc)
      end
    else
      doc[:data] = data
      store_dev_data_doc(col_name, query, doc)
    end
  end

  def store_dev_data_doc(col_name, query, doc)
    opts = {
      :upsert => true
    }
    # warn 'Inserting data ' + data.to_json
    @dev[col_name].update query, doc, opts
  end

  private

  LIVE_FILTER = {
    :live => 'live',
    :not_active => {
      :$nin => ['true', true]
    }
  }
    # :run_name => "20130603_112345_PDT_us_pod_batchsummary_bm01-130603-112346-kewule-423",
    # :view_id => "Iw1HPj"

  def dev_report_query(run, view)
    return {
      :run_name => run,
      :view_id => view
    }
  end

  def dev_report_data_query(id, timestamp)
    return {
      :report_id => id,
      :timestamp => timestamp
    }
  end

  def pack_data(data_rows)
    data = {}
    data_rows.each do |row|
      keys = row['data'].reject do |key| key.nil? or key == '' end
      keys = keys.map do |key|
        if not key.is_a?(String)
          key = key.to_s
        end
        key.gsub(".", "_!DOT_")
      end
      data = insert_data(data, keys, row['value'])
    end
    return data
  end

  def insert_data(obj, key_arr, val)
    cur_key = key_arr.shift
    return obj if cur_key.nil?
    if key_arr.length == 0
      # No more subkeys, insert value.
      obj[cur_key] = val if obj.is_a?(Hash)
    elsif key_arr.length > 0
      # Need to work out sub keys
      if not obj[cur_key].is_a?(Hash)
        obj.delete(cur_key)
      end
      if obj.has_key?(cur_key)
        insert_data(obj[cur_key], key_arr, val)
      else
        # Need to create new object to insert at key
        sub_obj = insert_data({}, key_arr, val)
        obj[cur_key] = sub_obj
      end
    end
    return obj
  end

  # Make sure report data collection has index
  def ensure_report_data_col(db, view_id, sub)
    col = dev_col_name(sub)
    warn 'ensuring index for ' + col
    # Create compound index on report_id and timestamp
    spec = {
      :report_id => Mongo::DESCENDING,
      :timestamp => Mongo::DESCENDING
    }
    opts = {
      :unique => true,
      :drop_dups => true
    }
    db[col].create_index(spec, opts)
  end

  # Production report collection name
  def prod_col_name(view_id, report)
    return "reports_#{view_id}_#{report}"
  end

  # Dev report collection name
  def dev_col_name(report)
    return "reports_#{report}"
  end

end


migrate = ReportMigrate.new
migrate.copy_reports
