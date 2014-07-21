require 'curb'

data = {
  data => {
    "factual_ids" => ["0656a5d0-cc2b-4fef-9206-f8d9f07b0220","bc66fdd7-4042-4650-b6fb-e32693bd5b2b"]
  }
}
c = Curl::Easy.http_put("http://ds-api.internal.factual.com/flag/Iw1HPj/50a10e9a-292b-4546-be72-8e80aa6981ee", data)
puts c.body_str
