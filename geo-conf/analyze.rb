require 'json'
require 'haversine'
require 'descriptive_statistics'

stats = []
entities =
  [
   {
     :file => "inputs-chez-panisse.json",
     :lat => 37.879589,
     :lng => -122.268988
   },
   {
     :file => "inputs-fairfax-high.json",
     :lat => 38.859932,
     :lng => -77.286118
   },
   {
     :file => "inputs-ghirardelli.json",
     :lat => 37.806084,
     :lng => -122.422957
   },
   {
     :file => "inputs-gjelina.json",
     :lat => 33.990731,
     :lng => -118.464931
   },
   {
     :file => "inputs-hof.json",
     :lat => 42.700039,
     :lng => -74.923188
   },
   {
     :file => "inputs-petco-park.json",
     :lat => 32.707804,
     :lng => -117.157065
   },
   {
     :file => "inputs-roosevelt.json",
     :lat => 34.101477,
     :lng => -118.341815
   },
   {
     :file => "inputs-staples-center.json",
     :lat => 34.101477,
     :lng => -118.341815
   },
   {
     :file => "inputs-stone.json",
     :lat => 33.115956,
     :lng => -117.119742
   },
   {
     :file => "inputs-target-field.json",
     :lat => 44.981819,
     :lng => -93.277392
   },
   {
     :file => "inputs-traif.json",
     :lat => 40.710791,
     :lng => -73.958946
   }
  ]

def analyze_entity_geo(stats, inputs, lat, lng)
  has_geo = 0
  has_conf = 0
  total = 0
  inputs.each_line do |line|
    input = JSON.parse line
    total += 1
    payload = input["payload"] or {}

    if payload["latitude"] and payload["longitude"]
      has_geo += 1
      key = -1
      if payload["geocode_confidence"]
        has_conf += 1
        key = payload["geocode_confidence"].to_i
      end

      # Compute distance from actual coords and store
      distance = Haversine.distance lat, lng, payload["latitude"].to_f, payload["longitude"].to_f
      mi = distance.to_miles
      stats[key] = stats[key] || []
      stats[key] << mi
    end
  end

  return has_geo, has_conf, total
end

def read_data_samples(entities)
  stats = {}
  has_geo = 0
  has_conf = 0
  total = 0
  entities.each do |entity|
    puts "File #{entity[:file]}\n"
    ifh = File.open entity[:file], 'r'
    e_geo, e_conf, e_total = analyze_entity_geo stats, ifh, entity[:lat], entity[:lng]
    ifh.close
    has_geo += e_geo
    has_conf += e_conf
    total += e_total
  end
  puts "Has geo: #{has_geo}\n"
  puts "Has conf: #{has_conf}\n"
  puts "Total: #{total}\n"
  return stats
end

def analyze_samples(stats)
  keys = stats.keys.sort
  keys.each do |key|
    key_stats = [ key, stats[key].mean, stats[key].variance, stats[key].standard_deviation, stats[key].length ]
    puts key_stats.join ","
  end
end

stats = read_data_samples entities
analyze_samples stats

