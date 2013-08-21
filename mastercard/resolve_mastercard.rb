require 'csv'
require 'tempfile'

require 'json'
require 'yaml'
require 'factual'
require 'spellchecker'

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
    if (args.has_key?('nlines'))
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
      puts "Resolving # #{@total}"
      payload = JSON.parse(line)
      payload = normalize_payload(payload);
      resolve_payload(payload)
    end

    @elapsed = (Time.now.to_f - start_time) * 1000.0
  end

  def print_stats()
    puts "Total rows: #{@total}"
    puts "Resolved rows: #{@num_resolved} written to #{@resolved.path}"
    puts "Resolved after mutating: #{@num_resolved_mutated}"
    puts "Resolved after spellcheck: #{@num_resolved_spellcheck}"
    puts "Resolved after removing name: #{@num_resolved_no_name}"
    puts "Unresolved rows: #{@num_unresolved} written to #{@unresolved.path}"
    puts "Time: #{@elapsed} ms"
  end

  private

  def isCSV(path)
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
      sample_file.write(JSON.generate(json_row) + "\n")
    end
    sample_file.close()
    puts "Generated #{nlines} inputs from #{src}"
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
    return {
      "id" => csv_row[UNIQUE_IDENTIFIER],
      "name" => csv_row[NAME],
      "address" => csv_row[ADDRESS],
      "region" => csv_row[STATE],
      "locality" => csv_row[CITY],
      "postcode" => csv_row[POST_CODE],
      "country" => csv_row[COUNTRY]
    }
  end

  def normalize_payload(payload)
    # Some localities are phone #s
    if /^\d{3,}/ =~ payload["locality"]
      payload['tel'] = payload['locality']
      payload.delete('locality')
    end

    # Zero pad postcode
    while payload['postcode'].length < 5
      payload['postcode'] = '0' + payload['postcode']
    end

    return payload
  end

  def resolve_payload(payload)
    orig_payload = payload.clone()
    write_result = {
      'id' => payload['id'],
      'resolve_payload' => orig_payload,
      'resolved' => false,
    }

    steps =
      [{ 'description' => 'basic',
         'payload' => lambda { |payload|
           return payload
         },
         'success' => lambda {|payload|}
       },
       { 'description' => 'mutate payload',
         'payload' => lambda {|payload|
           mutated = mutate_payload(payload);
           write_result['mutated_payload'] = mutated
           return mutated
         },
         'success' => lambda {|payload|
           @num_resolved_mutated += 1
         }
       },
       { 'description' => 'spellcheck',
         'payload' => lambda {|payload|
           spellchecked = spellcheck_payload(payload)
           write_result['spellchecked'] = spellchecked
           return spellchecked
         },
         'success' => lambda {|payload|
           @num_resolved_spellcheck += 1
         }
       },
       { 'description' => 'no name',
         'payload' => lambda {|payload|
           no_name = remove_name(payload)
           write_result['no_name'] = no_name
           return no_name
         },
         'success' => lambda {|payload|
           @num_resolved_no_name += 1
         }
       }
      ];

    steps.each do |step|
      resolved = perform_resolve_step(payload, write_result, step)
      return if resolved
    end

    @unresolved.write(JSON.generate(write_result) + "\n")
    @num_unresolved += 1
  end

  def perform_resolve_step(payload, write_result, step)
    step_payload = step['payload'].call(payload)
    #puts "Resolving with #{step['description']}, payload #{step_payload.inspect}\n"
    result = @factual.resolve(payload)
    if result.first && result.first['resolved']
      step['success'].call(step_payload)
      write_result['resolved'] = true
      write_result['result'] = result.rows[0]
      @num_resolved += 1
      @resolved.write(JSON.generate(write_result) + "\n")
      return true
    else
      return false
    end
  end

  def mutate_payload(payload)
    new_payload = payload.clone()
    # Remove long strings of numbers from name
    new_payload['name'].gsub!(/\d{5,}/, '')

    # Remove punctuation form name and address
    new_payload['name'].gsub!(/[\.,!?]/, '')
    new_payload['name'].gsub!(/[:;]/, ' ')
    new_payload['address'].gsub!(/[\.,!?]/, '')
    new_payload['address'].gsub!(/[:;]/, ' ')

    return new_payload
  end

  def spellcheck_payload(payload)
    payload['name'] = fix_spelling(payload['name'])
    payload['address'] = fix_spelling(payload['address'])
    return payload
  end

  def fix_spelling(words)
    corrected = Spellchecker.check(words)
    corrected_array = []
    corrected.each do |word_result|
      if word_result[:correct] == true || word_result[:suggestions].length <= 0
        corrected_array << word_result[:original]
      else
        corrected_array << word_result[:suggestions][0]
      end
    end
    #puts "Corrected: " + corrected_array.join(' ').to_s
    return corrected_array.join(' ')
  end

  def remove_name(payload)
    new_payload = payload.clone()
    new_payload.delete('name')
    return new_payload
  end

  def initialize_stats()
    @total = 0
    @num_resolved = 0
    @num_resolved_mutated = 0
    @num_resolved_spellcheck = 0
    @num_resolved_no_name = 0
    @num_unresolved = 0
  end
end
