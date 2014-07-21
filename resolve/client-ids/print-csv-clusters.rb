require 'csv'
require 'json'

STDIN.each do |line|
  cluster = JSON.parse line
  cluster.each do |input|
    row = [input["uuid"],
           input["md5"],
           input["payload"]["name"],
           input["payload"]["address"],
           input["payload"]["locality"],
           input["md5"],
           input["inputMeta"]["sourceUrl"]]
    puts CSV.generate_line(row)
  end
  puts "\n"
end
