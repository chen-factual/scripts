require 'json'

B0 = "b0"
B1 = "b1"
OVERALL = "overall"
SUMMARY_SCORE = "summary_score"
INPUT_OVERFOLD = "input-overfold-rate"
INPUT_REPULSION = "input-repulsion-score"
INPUT_COHESIVENESS = "input-cohesiveness-score"
SUMMARY_DUPE = "summary-dupe-rate"
SUMMARY_OVERFOLD = "summary-overfold-rate"

def attach_score(score)
  score[OVERALL] =
    score[INPUT_OVERFOLD] +
    score[INPUT_REPULSION] +
    score[INPUT_COHESIVENESS] +
    score[SUMMARY_DUPE] +
    score[SUMMARY_OVERFOLD] -
    2
  score[SUMMARY_SCORE] = score[SUMMARY_DUPE] + score[SUMMARY_OVERFOLD]
  return score
end

def read_results()
  b0 = nil
  b1 = nil
  results = []
  current = {}
  STDIN.each_line do |line|
    if m = /B0\s(\S+)\sB1\s(\S+)/.match(line)
      # If we had previous values, save them
      if not current[B0].nil? and not current[B1].nil?
        results << attach_score(current)
        current = {}
      end
      # Set constants
      current[B0] = m[1].to_f
      current[B1] = m[2].to_f
    elsif m = /:(.*):\s+(.*)/.match(line)
      field = m[1]
      value = m[2].to_f
      current[field] = value
    end
  end
  return results
end

def sort_results(results)
  return results.sort do |a, b|
    a[SUMMARY_SCORE] <=> b[SUMMARY_SCORE]
  end
end

def output(sorted)
  sorted.each do |scores|
    puts "B0: #{scores[B0]} B1: #{scores[B1]}\n"
    puts scores[INPUT_OVERFOLD].to_s + "\n"
    puts scores[INPUT_REPULSION].to_s + "\n"
    puts scores[INPUT_COHESIVENESS].to_s + "\n"
    puts scores[SUMMARY_DUPE].to_s + "\n"
    puts scores[SUMMARY_OVERFOLD].to_s + "\n"
    puts scores[OVERALL].to_s + "\n"
    puts scores[SUMMARY_SCORE].to_s + "\n"
  end
end

results = read_results()
sorted = sort_results(results)
output(sorted)
