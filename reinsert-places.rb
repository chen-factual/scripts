require 'date'
require 'net/http'
require 'rubygems'
require 'factual'
require 'json'

# Split line from log file and extract Factual key and place info
def parseLine(line)
  fields = Hash.new
  lineCols = line.split("\t")

  # Get originating user
  user = lineCols[5].scan(/user=(.*?)&/)
  fields[:user] = user[0][0]

  # Resolve table to insert to
  table = lineCols[4].scan(/\/(place.*?)\//)
  fields[:table] = table[0]

  # Parse fields out of JSON string
  jsonString = lineCols[5].scan(/\{.*?\}/)
  fields[:values] = JSON.parse(jsonString[0])
  fields[:values].delete('status')

  return fields
end

# Process lines from log file
def processLog()
  open('logfile', 'r').each do |line|
    fields = parseLine(line)

    user = fields[:user]
    table = fields[:table]
    values = fields[:values]

    # Print diagnostic
    puts "User: " + user
    puts "Table: " + table[0]
    puts "{ "
    values.each_pair { |key,value|
      puts "#{key} => #{value}"
    }
    puts "}\n\n"

    if user == 'feeds'
      # Push to DB via API
      #factual.submit(fields[:table], "feeds").values(values).write
    end
  end
end

# Query Dashboard for logs and process them
def getLog(query)
  url = "http://dashboard.factual.com/logs" + query
  puts url
  puts "wget \"#{url}\" -O logfile"
  #system "wget \"#{url}\" -O logfile"
  processLog()
end

def insert()
end



# Factual object for making inserts
$factual = Factual.new("NiOn9MBFSOIYOqWSk2KC9Njqr33inZREsq7T4dTg", "A7On5dBnJZkoHbdduFQ1XOZNWpC5xyZCKyOVQ1ND")

# From a start time, get logs by the hour and look for inserts that failed due to non_writable_field
date = Date.new(2013,3,20)

while date <= Date.today
  hour = 0
  while hour < 24
    query = "?type=api-post&range=hours&date=#{date}&hour=#{hour}&minutes=&toHour=#{hour}&minutes=&grep=non_writable_field"
    getLog(query)
    hour += 1
    exit
  end
  date += 1
end








