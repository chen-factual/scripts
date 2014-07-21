require 'json'
require 'curb'

nrows = ARGV[0] || 1000
params = {
  :q => "placerank_ml:[50 TO *]",
  :wt => "json",
  :fl => "factual_id",
  :rows => nrows
}
http = Curl.get("http://constellation.prod.factual.com/Iw1HPj-live/summaries/query", params)
resp = JSON.parse http.body_str
resp["response"]["docs"].each do |doc|
  puts doc["factual_id"]
end
