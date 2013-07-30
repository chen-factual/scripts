

$ifname = "./countries_grid.tab"
$ofname_base = "./country_polys/countries_"

$ifh = File.new($ifname, 'r')
$ofh_arr = []

for i in 0..17
  ofh = File.new($ofname_base + i.to_s + '.csv', 'w')
  $ofh_arr.push(ofh)
end

#ofh.write("country_code,lat_min,long_min,polygon\n")

def unroll_multi(wkt)
  matches = wkt.scan(/\(\([^\(\)]+\)\)/)
  return matches
end

# Write to different file based on latitude
def write_row(row, lat)
  file_no = (lat/10).floor + 9
  $ofh_arr[file_no].write(row + "\n")
end

while (line = $ifh.gets) do
  #print line
  matches = line.scan(/(.*?)\t(.*)/)
  if (matches[0][1] && matches[0][0] != 'country_code')
    poly = matches[0][1]
    points = poly.scan(/([-\d.]+)\s+([-\d.]+)/)

    lat_min = 90
    lat_max = -90
    long_min = 180
    long_max = -180

    points.each { |coord|
      long = coord[0].to_f
      lat = coord[1].to_f

      #print "Point: ", lat, ", ", long, "\n"

      if lat < lat_min
        lat_min = lat
      elsif lat > lat_max
        lat_max = lat
      end

      if long < long_min
        long_min = long
      elsif long > long_max
        long_max = long
      end
    }

    #print "Lat ", lat_min.floor, ", ", lat_max.ceil, "    "
    #print "Long ", long_min.floor, ", ", long_max.ceil, "\n"
    if (poly =~ /MULTIPOLYGON/i)
      unrolled = unroll_multi(poly)
      unrolled.each { |single|
        newPoly = "POLYGON" + single
        row = matches[0][0] + "," + lat_min.floor.to_s + "," + long_min.floor.to_s + ",\"" + newPoly + "\""
        write_row(row, lat_min.floor)
      }
    else
      # Use southwest corner as reference.
      row = matches[0][0] + "," + lat_min.floor.to_s + "," + long_min.floor.to_s + ",\"" + poly + "\""
      write_row(row, lat_min.floor)
    end
  end

end


