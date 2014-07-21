require 'dsapi'
require 'json'

$dsapi = DSAPI.new
INPUTS = ARGV[0]
NAME_URLS = ARGV[1]

def get_inputs(uuid)
  begin
    inputs = $dsapi.inputs_read('txIgmU', uuid, {:encoder => "thrift"})
  rescue
    inputs = get_inputs(uuid)
  end
  return inputs
end

count = 0
inputs_f = File.open(INPUTS, 'w')
name_urls_f = File.open(NAME_URLS, 'w')

STDIN.each_line do |uuid|
  uuid.gsub! /\n$/, ''
  urls = []
  filtered_inputs = []
  inputs = get_inputs uuid
  inputs.each do |input|
    if not input["inputMeta"]["sourceUrl"].nil? and
       not input["payload"]["name"].nil?
      urls << {
        :name => input["payload"]["name"],
        :url => input["inputMeta"]["sourceUrl"]
      }
    end
    if input["inputMeta"]["type"] == 'STANDARD' and
        (input["inputMeta"]["sourceId"].nil? or !/placerank/.match(input["inputMeta"]["sourceId"])) and
        (input["parentMd5"].nil? or input["parentMd5"] == input["md5"])
      filtered_inputs << input
    end
  end
  output = {
    :uuid => uuid,
    :urls => urls
  }
  name_urls_f.write JSON.generate(output) + "\n"

  write_inputs = {
    :uuid => uuid,
    :inputs => filtered_inputs
  }
  inputs_f.write JSON.generate(write_inputs) + "\n"
  count += 1
  warn "Count: #{count}" if count % 10 == 0
end
