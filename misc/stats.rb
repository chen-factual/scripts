require 'descriptive_statistics'

samples = []
ifh = File.open('conf', 'r')
ifh.each_line do |line|
  num = line.gsub("\"", "")
  samples << num.to_i
end
ifh.close

print "Mean #{samples.mean}\n"
print "Mode #{samples.mode}\n"
print "Var #{samples.variance}\n"
print "Stddev #{samples.standard_deviation}\n"
