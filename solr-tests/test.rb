require 'rsolr'
require 'json'

params = {
  q: "payload.name:bacon",
  wt: :ruby
}
response = RSolr.connect(url: "http://localhost:4000/Iw1HPj-kakuhu_prepped_dedupe_inputs/hew").get('query', params: params)
puts response
