require 'json'

# Some processsing on in-progress tasks in country distribution calculation

input = File.open(ARGV[0], 'r')
line = input.gets
json = JSON.parse(line)

puts json['tasks'].class()
started = 0
ended = 0
data = 0
total_size = 0

json['tasks'].each do |task|
  total_size += task['size']

  if !task['started'].nil?
    started += 1
  end

  if !task['ended'].nil?
    ended += 1
  end

  if task['data'].length > 0
    data += 1
  end

  if !task['started'].nil? && task['ended'].nil?
    puts "Worker: " + task['worker']
    puts "Ongoing task: " + task.to_json
  end
end

puts "Started: #{started}"
puts "Ended: #{ended}"
puts "Data: #{data}"
puts "Sum size: #{total_size}"
puts "Total size: #{json['status']['total']}"
