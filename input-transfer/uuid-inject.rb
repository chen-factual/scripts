require 'rubygems'
require 'json'

dataset = "ivSAHE"
view = "FJWgaL"

inputs = File.new(ARGV[0], 'r')
out = File.new(ARGV[1], 'w')
uuid = ''
while (line = inputs.gets)
  input = JSON.parse(line)
  uuid = input['uuid']
  input['datasetId'] = dataset
  input['inputMeta']['targetViewId'] = view
  input['processingState'] = "UNPROCESSED"
  input['payload'] = input['payloadRaw']
  input.delete 'payloadRaw'
  puts input['inputMeta']['type']
  out.write(JSON.generate(input) + "\n")
end
