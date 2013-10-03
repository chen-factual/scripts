require 'json'
require 'curl'

URL = "http://10.20.10.204:10000/t/places-us/resolve"
params = {
  :values => JSON.generate({
    "TerragoID" => "673",
    "name" => "St. John's Health Center",
    "category_labels" => "Health and Mental Health",
    "category_labels" => "Safe Havens",
    "Address" => "2121 Santa Monica Blvd",
    "city" => "Santa Monica",
    "zip" => "90404",
    "state" => "CA",
    "latitude" => "34.0302026057",
    "longitude" => "-118.479502201",
    "description" => "24 hours Emergency Services",
    "phone" => "Main Hospital Service/Intake (310) 829-5511, Physician Referral Service/Intake (888) 275-7542, Community Education Service/Intake (310) 829-8851, Breastfeeding classes/groups Service/Intake (310) 829-8944, Childbirth/New Parent/Breastfeeding Class sign u",
    "website" => "www.stjohns.org",
    "source" => "211"
  }),
  :KEY => "CJLWbo0xYFryJgRYT66MvGmLC0L1QbugeK2vNYZ7"
}

puts "params #{params}"
resp = Curl.post(URL, params)
puts resp.body_str
puts resp.response_code

