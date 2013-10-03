require 'net/http'
require 'json'

year = ARGV[0]
month = ARGV[1]
file = ARGV[2]

json_str = File.open(file, 'r').first
tasks = JSON.parse(json_str)
stats = tasks['data']
stats[:date] = "#{year}#{month.to_i < 10 ? '0'+month.to_s : month}"
puts stats.to_json

SUBMIT_URI = URI("http://dashboard.prod.factual.com/submit/mm-billing")
p Net::HTTP.post_form(SUBMIT_URI, :data => stats.to_json)
