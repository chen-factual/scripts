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
    reports = @stitch_reports.find CUST_FILTER
    warn "Found " + reports.count.to_s + " reports"
    reports.each do |report|
      if ALLOWED_REPORTS.include? report['report_name']
        # TODO: Whitelist reports
      end
      report = find_latest_report(report)
      dev_report = create_dev_report(report)
      copy_report_data(report, dev_report)
    end
  end

  # Find latest report for this build, view, and report type
  def find_latest_report report
    query = {
      :run_name => report["run_name"],
      :view_id => report["view_id"],
      :report_name => report["report_name"]
    }
    opts = {
      :sort => [["created_at", Mongo::DESCENDING]],
      :limit => 1
    }
    reports = @stitch_reports.find query, opts
    return reports.next
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

  # For existing build reports entry in dev DB,
  # update it with a new report
  def update_dev_report(query, report)
    sub_report = report['report_name']
    dev_report = get_dev_report(query)
    update_doc = {
      :$set => {
        "reports.#{sub_report}" => true
      }
    }
    if sub_report == 'data_quality_metrics_accuracy'
      update_doc = update_dqm_doc(update_doc, dev_report, report)
    end
    @dev_reports.update(query, update_doc)
  end

  # Extend the Mongo update document with DQM info
  def update_dqm_doc(update_doc, dev_report, report)
    code_ver = report['config']['dqm__code_sha']
    data_ver = report['config']['dqm__data_sha'] || report['config']['dqm_inputs_version']
    dqmReports = dev_report["dqm_versions"] || []
    data = dev_report_data(report)
    data.each_pair do |metal, metal_data|
      match = dqmReports.select do |cfg|
        cfg["code_sha"] == code_ver &&
        cfg["dqm_inputs_version"] == data_ver &&
        cfg["metal"] == metal
      end
      if match.length == 0
        dqmReports << {
          "code_sha" => code_ver,
          "dqm_inputs_version" => data_ver,
          "metal" => metal
        }
      end
    end
    update_doc[:$set][:dqm_versions] = dqmReports
    return update_doc
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
      $stderr.puts "Execption: " + e.message
      $stderr.puts "Failed to store data: #{prod_report['run_name']} #{report['view_id']} #{sub}"
      $stderr.puts 'Failed to store data: ' + prod_report.to_s
      $stderr.puts 'Failed to store data: ' + data.to_s
    end

  end

  def dev_report_data(prod_report)
    data_cursor = get_prod_data(prod_report['_id'], prod_report['view_id'], prod_report['report_name'])
    warn "report #{prod_report['_id']} #{prod_report['report_name']} num data rows " + data_cursor.count.to_s
    if prod_report['report_name'] == 'top_records'
      return top_records_data(data_cursor)
    else
      return pack_data(data_cursor)
    end
  end

  # REPORTS

  def get_dev_reports()
    reports = @dev_reports.find
    warn 'num dev reports ' + reports.count.to_s
    return reports
  end

  def get_dev_report(query)
    return @dev_reports.find(query).next
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

  # Retrieve data from prod DB
  def get_prod_data(id, view_id, report)
    col_name = prod_col_name(view_id, report)
    query = { :report_id => id }
    prod_data = @stitch[col_name].find query
    return prod_data
  end

  # Store report data into target dev DB
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
        query[:config] = { :metal => metal }
        warn "DQM: storing #{id} #{timestamp} #{metal}"
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
    begin
      @dev[col_name].update query, doc, opts
    rescue Exception => e
      $stderr.puts "Exception: " + e.message
      $stderr.puts "Trying to store: " + doc.to_s
    end
  end

  private

  LIVE_FILTER = {
    :live => 'live',
    :not_active => {
      :$nin => ['true', true]
    }
  }

  PROD_FILTER = {
    :run_name => /batchsummary/
  }

  CUST_FILTER = {
    # :run_name => "origin-stats"
    :run_name => /ninipo/,
    :view_id => 'Iw1HPj'
  }

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

  def top_records_data(data_cursor)
    data_doc = data_cursor.next
    data = {}
    data_doc.each_pair do |key, val|
      # Copy core data key-vals
      if key != '_id' and key != 'report_id'
        data[key] = val
      end
    end
    return data
  end

  def pack_data(data_cursor)
    data = {}
    data_cursor.each do |row|
      begin
        keys = row['data'].reject do |key| key.nil? or key == '' end
        keys = keys.map do |key|
          if not key.is_a?(String)
            key = key.to_s
          end
          key.gsub(".", "_!DOT_")
        end
        data = insert_data(data, keys, row['value'])
      rescue Exception => e
        $stderr.puts "Failed to pack row " + row.to_s
      end
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
    # warn 'ensuring index for ' + col
    # Create compound index on report_id and timestamp
    spec = {
      :report_id => Mongo::DESCENDING,
      :timestamp => Mongo::DESCENDING
    }
    opts = {}
    if sub != 'data_quality_metrics_accuracy'
      # spec["config.metal"] = Mongo::HASHED
      # spec["config.code_sha"] = Mongo::HASHED
      # spec["config.dqm_inputs_version"] = Mongo::HASHED
      opts = {
        :unique => true,
        :drop_dups => true
      }
    end
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
