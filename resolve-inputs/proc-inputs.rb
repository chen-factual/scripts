require 'json'

class Stats
  def initialize(file, n_summaries = 500)
    @inputs = {}
    @results = {}
    @file = file
    @n = n_summaries
  end

  def run()
    read_inputs()
    process_inputs()
  end

  def print_results()
    puts JSON.pretty_generate(@results)
  end

  private

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

  def compare_with_rest(val1, idx1)
    @inputs.each do |idx2, cluster|
      cluster.each do |val2|
        result = compare(val1, val2)
        record(result, idx1, idx2)
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

  def record(result, idx1, idx2)
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

    return common_cats / max_len.to_f
  end

  def record(result, idx1, idx2)
    @results[result] = [0, 0] if @results[result].nil?

    if idx1 == idx2
      @results[result][0] += 1
    else
      @results[result][1] += 1
    end
  end
end

#stats = PhoneStats.new(ARGV[0], 500)
stats = CategoryStats.new(ARGV[0], 500)
stats.run()
stats.print_results()
