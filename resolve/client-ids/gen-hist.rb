require 'json'

# For domain, tally how many distinct IDs there are for this
# summary
def handle_domain(domains, domain, ids)
  domains[domain] = [] if domains[domain].nil?
  count = ids.length
  domains[domain][count] = 0 if domains[domain][count].nil?
  domains[domain][count] += 1
end

# For a summary, tally how many domains have distinct IDs
def handle_summary(summaries, ids)
  multi_ids = []
  ids.each do |domain, dom_ids|
    # Record if domain has at least I ids
    for i in 0..dom_ids.length
      multi_ids[i] = 0 if multi_ids[i].nil?
      multi_ids[i] += 1
    end
  end
  # Index in multi_ids indicate how many distinct IDs,
  # count at index indicate how many domains
  multi_ids.each_with_index do |num_domains, num_ids|
    num_domains = 0 if num_domains.nil?
    for i in 0..num_domains
      summaries[num_ids] = [] if summaries[num_ids].nil?
      summaries[num_ids][i] = 0 if summaries[num_ids][i].nil?
      summaries[num_ids][i] += 1
    end
  end
end

domains = {}
summaries = []
STDIN.each_line do |line|
  entry = JSON.parse line
  ids = entry["ids"]
  ids.each do |domain, dom_ids|
    handle_domain(domains, domain, dom_ids)
  end
  handle_summary(summaries, ids)
end

DOMAIN_HIST = ARGV[0]
SUMMARY_HIST = ARGV[1]

File.open(DOMAIN_HIST, 'w') do |file|
  file.write JSON.generate(domains)
end

File.open(SUMMARY_HIST, 'w') do |file|
  file.write JSON.generate(summaries)
end
