require 'json'
require 'mongo'
require 'bson'
include Mongo

class ReportMigrate

  HOST_NAME = 'mongo1'
  HOST_PORT = 27017
  STITCH_DB = 'stitch'
  DEV_DB = 'stitch-cg'

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
    reports.each do |report|
      run = report['run_name']
      view = report['view_id']
      rep = report['report_name']
      if new_reports[run].nil?
        new_reports[run] = {}
      end
      if new_reports[run][view].nil?
        new_reports[run][view] = {}
      end
      new_reports[run][view][rep] = true
    end

    new_reports.each_pair do |run, view_data|
      view_data.each_pair do |view, report_data|
        query = {
          :run_name => run,
          :view_id => view
        }
        new_report = {
          :run_name => run,
          :view_id => view,
          :reports => report_data
        }
        opts = {
          :continue_on_error => true,
          :upsert => true
        }
        @dev_reports.update query, new_report, opts
      end
    end

  end

  # Copy data for reports
  def copy_report_data()
    get_dev_reports().each do |report|
      subreports = report['reports']
      run_name = report['run_name']
      view_id = report['view_id']
      report_id = report['_id']
      warn 'getting data for dev report ' + report_id.to_s
      subreports.each_pair do |sub, _|
        warn 'copying sub ' + sub
        # Ensure collection has desired index built
        ensure_report_data_col(@dev, view_id, sub)
        prod_report = get_prod_report(run_name, view_id, sub)
        data = get_prod_data(prod_report['_id'], view_id, sub)
        packed_data = pack_data(data)
        timestamp = prod_report['created_at'] || prod_report['insert_time']
        begin
          store_dev_data(sub, report_id, packed_data, timestamp)
        rescue Exception => e
          warn "Execption: " + e.message
          warn "Failed to store data: #{run_name} #{view_id} #{sub} #{timestamp}"
          warn 'Failed to store data: ' + packed_data.to_s
        end
      end
    end
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

  def store_dev_data(report_name, id, data, timestamp)
    col_name = dev_col_name(report_name)
    query = {
      :report_id => id,
      :timestamp => timestamp
    }
    doc = {
      :report_id => id,
      :data => data,
      :timestamp => timestamp
    }
    opts = {
      :upsert => true
    }
    warn 'Inserting data ' + data.to_s
    @dev[col_name].update query, doc, opts
  end

  private

  LIVE_FILTER = {
    :live => 'live',
    :not_active => {
      :$nin => ['true', true]
    }
  }

  def pack_data(data_rows)
    data = {}
    # begin
    warn 'num data rows ' + data_rows.count.to_s
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
    # warn 'packed ' + data.to_json
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
      if obj[cur_key].is_a?(Hash)
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

  def prod_col_name(view_id, report)
    return "reports_#{view_id}_#{report}"
  end

  def dev_col_name(report)
    return "reports_#{report}"
  end

end


migrate = ReportMigrate.new
migrate.copy_reports
migrate.copy_report_data
