require 'optparse'
require './resolve_mastercard.rb'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage:
  generate NLINES random samples from source CSV file to sample.json and resolve
    run.rb -n NLINES -f SOURCE_CSV_FILE
  resolve from saved sample.json file
    run.rb -f SAVED_JSON_FILE\n\n"

  opts.on("-n", "NLINES to generate from CSV input") do |n|
    options[:nlines] = n
  end

  opts.on("-f", "input file") do |file|
    options[:src] = file
  end
end.parse!

nlines = ARGV[0]
source = ARGV[1]

analyzer = MCAnalyzer.new('nlines' => nlines, 'src' => source)
analyzer.resolve()
analyzer.print_stats()
