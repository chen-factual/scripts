require 'json'
require 'haversine'

class Stats
  def initialize(file, n_summaries = 500)
    @inputs = {}
    @results = {}
    @file = file
    @n = n_summaries
    read_inputs()
  end

  # Compare inputs with all other inputs
  def process_inputs()
    @inputs.each do |idx, cluster|
      cluster.each do |val|
        compare_with_rest(val, idx)
      end
      if idx % 25 == 0
        puts idx
      end
    end
  end

  # Compare inputs of a single cluster
  def process_summaries()
    @inputs.each do |idx, cluster|
      for i in 0..cluster.length
        for j in i..cluster.length
          result = compare(cluster[i], cluster[j])
          if not result.nil?
            record_summaries(result)
          end
        end
      end
    end
  end

  def print_results()
    puts JSON.pretty_generate(@results)
  end

  private

  # Parse file of input clusters into map
  # of cluster to array of its inputs
  def read_inputs()
    clusterFile = File.open(@file, 'r')
    idx = 0
    total = 0

    clusterFile.each do |line|
      @inputs[idx] = []

      cluster = JSON.parse(line)
      cluster['inputs'].each do |input|
        value = extract(input)
        @inputs[idx] << value
        total += 1
      end

      idx += 1
      break if idx > @n
    end

    puts "Processed #{total} inputs"
    clusterFile.close()
  end

  def compare_with_rest(val1, idx1)
    @inputs.each do |idx2, cluster|
      cluster.each do |val2|
        result = compare(val1, val2)
        if not result.nil?
          record_input(result, idx1, idx2)
        end
      end
    end
  end

end

class PhoneStats < Stats

  def extract(input)
    return input["payload"]["phone"] || input["payload"]["tel"]
  end

  def compare(str1, str2)
    if str1.nil? || str2.nil?
      return [0, 0]
    end

    str1 = str1.gsub(/[^a-zA-Z0-9]/, '')
    str2 = str2.gsub(/[^a-zA-Z0-9]/, '')

    len = [str1.length, str2.length].min
    cmp_str1 = str1[-len, len]
    cmp_str2 = str2[-len, len]

    matches = 0
    (0..len-1).each do |i|
      if cmp_str1[i] == cmp_str2[i]
        matches += 1
      end
    end

    return [len, matches]
  end

  def record_input(result, idx1, idx2)
    len = result[0]
    matches = result[1]
    @results[len] = {} if @results[len].nil?
    @results[len][matches] = [0, 0] if @results[len][matches].nil?

    if idx1 == idx2
      @results[len][matches][0] += 1
    else
      @results[len][matches][1] += 1
    end
  end

  def record_summaries(result)
    len = result[0]
    matches = result[1]

    @results[len][matches] = 0 if @results[len][matches].nil?
    @results[len][matches] += 1
  end

end

class CategoryStats < Stats
  def extract(input)
    return input["payload"]["category"]
  end

  def compare(cat1, cat2)
    if cat1.nil? || cat2.nil?
      return nil
    end

    cats1 = cat1.split(/\s*>\s*/)
    cats2 = cat2.split(/\s*>\s*/)

    max_len = [cats1.length, cats2.length].max
    min_len = [cats1.length, cats2.length].min

    common_cats = 0
    (0..min_len-1).each do |idx|
      if cats1[idx] == cats2[idx]
        common_cats += 1
      else
        break
      end
    end


    # puts "Cat #{common_cats} min #{min_len} max #{max_len} cat/min #{common_cats / min_len.to_f} cat/max #{common_cats / max_len.to_f}"
    min_max_avg = (min_len + max_len) / 2.0
    # return common_cats / min_max_avg
    # return common_cats / min_len.to_f
    return common_cats / max_len.to_f
  end

  def record_input(result, idx1, idx2)
    @results[result] = [0, 0] if @results[result].nil?

    if idx1 == idx2
      @results[result][0] += 1
    else
      @results[result][1] += 1
    end
  end

  def record_summaries(result)
    @results[result] = 0 if @results[result].nil?
    @results[result] += 1
  end

end

class PostcodeStats < Stats

  def extract(input)
    return input["payload"]["postcode"]
  end

  def compare(code1, code2)
    if code1.nil? or code2.nil?
      return nil
    end

    min_len = [code1.length, code2.length].min
    max_len = [code1.length, code2.length].max
    matches = 0
    for i in 1..min_len
      if code1[i] == code2[i]
        matches += 1
      end
    end

    return [max_len, matches]
  end

  def record_input(result, idx1, idx2)
    len = result[0]
    matches = result[1]
    @results[len] = {} if @results[len].nil?

    @results[len][matches] = [0, 0] if @results[len][matches].nil?
    if idx1 == idx2
      @results[len][matches][0] += 1
    else
      @results[len][matches][1] += 1
    end
  end

  def record_summaries(result)
    len = result[0]
    matches = result[1]

    @results[len] = {} if @results[len].nil?
    @results[len][matches] = 0 if @results[len][matches].nil?
    @results[len][matches] += 1
  end
end

class LatLongStats < Stats

  def initialize(file, n_summaries = 500)
    super
    @results = {
      0.0 => [0, 0],
      0.5 => [0, 0],
      1.0 => [0, 0],
      1.5 => [0, 0],
      2.0 => [0, 0],
      2.5 => [0, 0],
      3.0 => [0, 0],
      3.5 => [0, 0],
      4.0 => [0, 0],
      4.5 => [0, 0],
      5.0 => [0, 0],
      5.5 => [0, 0],
      6.0 => [0, 0],
      6.5 => [0, 0],
      7.0 => [0, 0],
      7.5 => [0, 0],
      8.0 => [0, 0],
      8.5 => [0, 0],
      9.0 => [0, 0],
      9.5 => [0, 0],
      10.0 => [0, 0]
    }
  end

  def extract(input)
    coords = {
      :lat => input["payload"]["latitude"].to_f,
      :lng => input["payload"]["longitude"].to_f,
      :conf => input["payload"]["geocode_confidence"]
    }
    return coords
  end

  def compare(coords1, coords2)
    if coords1.nil? or coords2.nil?
      return -1
    end

    distance = Haversine.distance(coords1[:lat], coords1[:lng],
                                  coords2[:lat], coords2[:lng])
    begin
      conf = [coords1[:conf], coords2[:conf]].min
    rescue
      conf = 0
    end
    return [distance.to_miles, conf]
  end

  def round_to_half(num)
    return (num * 2).to_i / 2.0
  end

  def round_to_quarter(num)
    return (num * 4).to_i / 4.0
  end

  def round_to_tenths(num)
    return (num * 10).to_i / 10.0
  end

  def record_input(result, idx1, idx2)
    result_idx = (idx1 == idx2)? 0 : 1
    return if result[0] < 0.03
    rounded = round_to_quarter(result[0])
    if rounded <= 10.0
      if @results[rounded].nil?
        @results[rounded] = [0, 0]
      end
      @results[rounded][result_idx] += 1
    end
  end

  def record_summaries(result)
    # Skip summaries too close together (they'd be combined)
    return if result[0] < 0.03
    rounded = round_to_tenths(result[0])
    if rounded <= 1.0
      if @results[rounded].nil?
        @results[rounded] = [0, 0]
      end
      @results[rounded][0] += 1
    end
  end

  def print_results()
    puts JSON.pretty_generate(@results)
  end

end

def usage()
  print "Usage: proc-inputs.rb FIELD INPUTS_FILE\n"
end

if ARGV[0] == '--help'
  usage()
  exit 0
end

FIELD = ARGV[0]
FILE = ARGV[1]

stats = nil
case FIELD
when 'phone'
  stats = PhoneStats.new(FILE, 500)
when 'category'
  stats = CategoryStats.new(FILE, 5000)
when 'postcode'
  stats = PostcodeStats.new(FILE, 500)
when 'latlng'
  stats = LatLongStats.new(FILE, 500)
else
  print "Unsupported field to process: #{FIELD}\n"
end

if not stats.nil?
  stats.process_inputs()
  # stats.process_summaries()
  stats.print_results()
end
