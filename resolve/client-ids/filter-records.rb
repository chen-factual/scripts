require 'json'

INPUTS = ARGV[0]
MIN_IDS = ARGV[1].to_i
MIN_DOMS = ARGV[2].to_i

def read_inputs()
  inputs = {}
  ifh = File.open(INPUTS, 'r')
  ifh.each do |line|
    cluster = JSON.parse line
    uuid = cluster["uuid"]
    inputs[uuid] = cluster["inputs"]
  end
  ifh.close
  return inputs
end

begin
  inputs = read_inputs()
rescue e
  warn "read error"
end

filtered = []
STDIN.each do |line|
  record = JSON.parse line
  domains = 0
  record["ids"].each_pair do |domain, ids|
    if ids.length >= MIN_IDS
      domains += 1
    end
  end
  if domains >= MIN_DOMS
    filtered << inputs[record["uuid"]]
  end
end

filtered.each do |record|
  puts record.to_json + "\n"
end
