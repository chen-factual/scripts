require 'json'

$results = {}

def read_inputs(file)
  clusterFile = File.open(file, 'r')
  inputs = {}

  idx = 0
  total = 0

  clusterFile.each do |line|
    inputs[idx] = []

    cluster = JSON.parse(line)
    cluster['inputs'].each do |input|
      phone = input["payload"]["phone"] || input["payload"]["tel"]
      inputs[idx] << phone
      total += 1
    end

    idx += 1
    break if idx > 500
  end

  puts "Processed #{total} inputs"
  return inputs
end

def record_result(len, matches, idx1, idx2)
  $results[len] = {} if $results[len].nil?
  $results[len][matches] = [0, 0] if $results[len][matches].nil?

  if idx1 == idx2
    $results[len][matches][0] += 1
  else
    $results[len][matches][1] += 1
  end
end

def phone_match(str1, str2)
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

def compare_with_rest(inputs, phone1, idx1)
  inputs.each do |idx2, cluster|
    cluster.each do |phone2|
      match = phone_match(phone1, phone2)
      record_result(match[0], match[1], idx1, idx2)
    end
  end
end

def process_inputs(inputs)
  inputs.each do |idx, cluster|
    cluster.each do |phone|
      compare_with_rest(inputs, phone, idx)
    end
    if idx % 25 == 0
      puts idx
    end
  end
end

inputs = read_inputs(ARGV[0])
process_inputs(inputs)
puts $results
