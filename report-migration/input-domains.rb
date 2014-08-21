require 'json'
require 'mongo'
require 'bson'

include Mongo

class InputDomainsMigrate

  HOST_NAME = 'mongo1'
  HOST_PORT = 27017
  STITCH_DB = 'stitch'

  def initialize()
    server = MongoClient.new HOST_NAME, HOST_PORT
    @stitch = server[STITCH_DB]
    @stitch_reports = @stitch.collection 'reports'
    warn 'initialization successful'
    @no_src = 0
    @processed = 0
  end

  def migrate()
    reports = find_input_tabs()
    reports.each do |query|
      input_tabs_report = find_report(query)
      if not input_tabs_report.nil?
        query.delete('created_at')
        view = input_tabs_report['view_id']
        run_name = input_tabs_report['run_name']
        input_report_id = input_tabs_report['_id']
        sources_report_id = find_sources_report(input_tabs_report)
        @processed += 1
        warn "#{@processed}: #{view} #{run_name} #{input_report_id} #{sources_report_id}"
        copy_input_data(view, input_report_id, sources_report_id)
      end
    end
  end

  def clean()
    cols = @stitch.collection_names
    cols.each do |col|
      if col.match /sources_tab/
        warn "Cleaning #{col}"
        query = {
          :data => {
            :$in => ["input_origin_domains", "input_origin_totals", "input_domain_totals"]
          }
        }
        result = @stitch[col].remove query
        warn "result: #{result}"
      end
    end
  end

  def clean_input_tab()
    cols = @stitch.collection_names
    cols.each do |col|
      if col.match /inputs_tab/
        result = @stitch[col].drop
      end
    end
    query = { :report_name => "inputs_tab" }
    @stitch_reports.remove query
  end

  def count()
    cols = @stitch.collection_names
    cols.each do |col|
      if col.match /reports_/
        docs = @stitch[col].count
        warn "col #{col} docs: #{docs}"
      end
    end
  end

  private

  # Find all of the latest input_tab reports
  def find_input_tabs()
    match = {
      :$match => {
        :report_name => 'inputs_tab'
      }
    }
    group = {
      :$group => {
        :_id => {
          :run_name => '$run_name',
          :view_id => '$view_id'
        },
        :created_at => {
          :$max => '$created_at'
        }
      }
    }
    project = {
      :$project => {
        :_id => 0,
        :run_name => '$_id.run_name',
        :view_id => '$_id.view_id',
        :created_at => '$created_at'
      }
    }
    matches = @stitch_reports.aggregate [match, group, project]
    warn 'input tab reports ' + matches.length.to_s
    return matches
  end

  def find_report(query)
    report = @stitch_reports.find_one(query)
    return report
  end

  def find_sources_report(inputs_report)
    query = {
      :run_name => inputs_report['run_name'],
      :view_id => inputs_report['view_id'],
      :report_name => 'sources_tab'
    }
    opts = {
      :sort => ['created_at', -1]
    }
    report = @stitch_reports.find(query, opts)
    if report.count == 0
      @no_src += 1
      warn 'No sources report found: ' + @no_src.to_s
      return create_sources_report(inputs_report)
    else
      return report.next["_id"]
    end
  end

  def create_sources_report(inputs_report)
    sources_report = inputs_report.clone
    sources_report.delete('_id')
    sources_report['report_name'] = 'sources_tab'
    warn "Injecting sources #{sources_report}"
    return @stitch_reports.insert(sources_report)
  end

  def copy_input_data(view, input_report_id, sources_report_id)
    data = get_input_data(view, input_report_id)
    # warn "data rows: #{data.length}"
    converted = convert_data(data, sources_report_id)
    inject_sources_data(converted, view)
  end

  def get_input_data(view, input_report_id)
    input_tab_col = "reports_#{view}_inputs_tab"
    query = { :report_id => input_report_id }
    data = @stitch[input_tab_col].find(query)
    return data.to_a
  end

  def inject_sources_data(data, view)
    sources_tab_col = "reports_#{view}_sources_tab"
    result = @stitch[sources_tab_col].insert(data)
  end

  def convert_data(data, sources_report_id)
    new_data_lines = []
    data.each do |data_line|
      data_line.delete("_id")
      data_line["report_id"] = sources_report_id
      data = data_line["data"]
      if data[0] == "All"
        domain = data[1]
        next if domain == 'total'
        new_data = ['input_domain_totals', domain]
      else
        origin = data[0]
        domain = data[1]
        if domain == 'total'
          new_data = ['input_origin_totals', origin]
        else
          new_data = ['input_origin_domains', origin, domain]
        end
      end
      data_line["data"] = new_data
      new_data_lines << data_line
    end
    # warn "data lines: #{new_data_lines.join("\n")}"
    return new_data_lines
  end

end

migrator = InputDomainsMigrate.new
# migrator.migrate
# migrator.clean
# migrator.count
# migrator.clean_input_tab

