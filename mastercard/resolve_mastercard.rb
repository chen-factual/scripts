require 'csv'

require 'rubygems'
require 'json'
require 'yaml'
require 'factual'

class MCAnalyzer
  AUTH_FILE = '~/.factual/factual-auth.yaml'
  SAMPLE = 'sample.json'
  RESOLVED = 'resolved.json'
  UNRESOLVED = 'unresolved.json'

  UNIQUE_IDENTIFIER = 0
  OLD_LOC_ID = 1
  MMH_LOCATION = 2
  MCC_CODE = 3
  NAME = 4
  ADDRESS = 5
  CITY = 6
  STATE = 7
  POST_CODE = 8
  COUNTRY = 9

  def initialize(args)
    if (isCSV(args['src']))
      generate_samples(args['nlines'], args['src'])
    else
      @samples = File.open(args['src'], 'r')
    end

    initialize_api()
    initialize_output()
  end

  def resolve()
    initialize_stats()
    start_time = Time.now.to_f

    @samples.each_line do |line|
      @total += 1
      payload = JSON.parse(line)
      write_result = {
        'id' => payload['id'],
        'resolve_payload' => payload,
        'resolved' => false,
      }

      result = @factual.resolve(payload)
      if result.first && result.first['resolved']
        write_result['resolved'] = true
        write_result['result'] = result.rows[0]
        @resolved.write(JSON.generate(write_result) + "\n")
        @num_resolved += 1
      else
        @unresolved.write(JSON.generate(write_result) + "\n")
        @num_unresolved += 1
      end
    end

    @elapsed = (Time.now.to_f - start_time) * 1000.0
  end

  def print_stats()
    puts "Total rows: #{@total}"
    puts "Resolved rows: #{@num_resolved} written to #{@resolved.path}"
    puts "Unresolved rows: #{@num_unresolved} written to #{@unresolved.path}"
    puts "Time: #{@elapsed} ms"
  end

  private

  def isCSV(path)
    puts path
    return /\.csv$/i =~ path
  end

  def run_cmd(cmd)
    puts "Command: #{cmd}"
    system(cmd)
    throw "System command failed" if $? != 0
  end

  def generate_samples(nlines, src)
    sample_file = File.open(SAMPLE, 'w')
    `shuf -n #{nlines} #{src}`.split("\n").each do |line|
      csv_row = CSV.parse_line(line)
      json_row = get_json_row(csv_row)
      sample_file.write(json_row + "\n")
    end
    sample_file.close()
    @samples = File.open(SAMPLE, 'r')
  end

  def initialize_api()
    begin
      cfg = YAML.load_file(File.expand_path(AUTH_FILE, __FILE__))
      @factual = Factual.new(cfg['key'], cfg['secret'])
    rescue
      throw "Failed to load Factual API authentication"
    end
  end

  def initialize_output()
    @resolved = File.open(RESOLVED, 'w')
    @unresolved = File.open(UNRESOLVED, 'w')
  end

  def get_json_row(csv_row)
    payload = {
      "id" => csv_row[UNIQUE_IDENTIFIER],
      "name" => csv_row[NAME],
      "address" => csv_row[ADDRESS],
      "locality" => csv_row[CITY],
      "region" => csv_row[STATE],
      "postcode" => csv_row[POST_CODE],
      "country" => csv_row[COUNTRY]
    }
    return JSON.generate(payload)
  end

  def initialize_stats()
    @total = 0
    @num_resolved = 0
    @num_unresolved = 0
  end

end

NLINES = 1000
SOURCE = "test_data.csv"
#SOURCE = "sample.json"

analyzer = MCAnalyzer.new('nlines' => NLINES, 'src' => SOURCE)
analyzer.resolve()
analyzer.print_stats()
