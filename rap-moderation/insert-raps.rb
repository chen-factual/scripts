require 'json'
require 'curl'

BASE_URL = "http://ds-api.internal.factual.com/flag/0EwHGb/"
APPLE_ID = "19d1601b-32b1-4777-9ddf-2634bf3ea94b"
AU_DS_ID = "ds-places-au"

def get_issue_type(problem)
  case problem
  when "P_DOES_NOT_EXIST_CLOSED"
    return "deletion"
  when "P_DOES_NOT_EXIST_OTHER"
    return "deletion"
  when "P_INCORRECT_INFO"
    return "inaccurate"
  when "P_INCORRECT_PIN_LOCATION"
    return "inaccurate"
  when "P_NOT_LISTED"
    return "nonexistent"
  else
    return ""
  end
end

inputs = File.new(ARGV[0], 'r')

inputs.each do |line|
  json = JSON.parse(line)
  # puts JSON.pretty_generate(json)
  params = {
    "partner-id" => APPLE_ID,
    "user-id" => "apple",
    "dataset-id" => AU_DS_ID,
  }
  params["problem"] = get_issue_type(json["customer_pin_problem"])
  if (!json["comments"].nil? and json["comments"] != "nocomments")
    params["comment"] = json["comments"]
  end
  params["params"] = {
    "problem_type" => json["customer_pin_problem"]
  }

  url = BASE_URL + json["factual_id"]

  puts "Problem " + json["customer_pin_problem"] + " Translated " + params["problem"]

  puts "URL: " + url
  # puts "Params: " + JSON.pretty_generate(params)

  resp = Curl.post(url, params)
  puts resp.response_code
end




