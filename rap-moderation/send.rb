require 'json'
require 'curl'

URL = "http://ds-api.internal.factual.com/flag/0EwHGb/f96777e1-96d9-4fe3-9c37-7f1634534d40"
params = {
  "problem" => "correction",
  "dataset-id" => "ds-places-au",
  "user-id" => "19d1601b-32b1-4777-9ddf-2634bf3ea94b",
  "partner-id" => "19d1601b-32b1-4777-9ddf-2634bf3ea94b",
  "params" => {
    "dataProblemType" => [ 18 ]
  }
}

resp = Curl.post(URL, params)
puts resp.body_str
puts resp.response_code

