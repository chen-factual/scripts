require 'json'
require 'curb'

cluster = ARGV[0]
cluster_file = File.open("#{cluster}/clusters.json")

cluster_file.each_line do |line|
  cluster_json = JSON.parse(line)
  inputs = cluster_json["inputs"]
  input_strs = inputs.map { |input|
    input.delete("inferred")
    input["processingState"] = "FULL_PROCESSED"
    input["datasetId"] = "txIgmU"
    JSON.generate(input)
  }
  data = input_strs.join("\n")
  print data
  c = Curl::Easy.http_put("http://ds-api.internal.factual.com/summarize/txIgmU", data)
  puts c.body_str
end



