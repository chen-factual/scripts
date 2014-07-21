require 'json'

def parse_result(domain, id)
  return { :domain => domain, :id => id }
end

def parse_last_seg(domain, url)
  match = url.match /([^\/#?]+)([#?].*)?$/
  if not match.nil?
    return parse_result domain, match[1]
  end
end

def parse_yahoo(url)
  match = url.match /info-(\d+)/
  if not match.nil?
    return parse_result 'yahoo', match[1]
  end
end

def parse_twitter(url)
  match = url.match /([^\/]+)\.json/
  if not match.nil?
    return parse_result 'twitter', match[1]
  end
end

def parse_foursquare(url)
  return parse_last_seg 'foursquare', url
end

def parse_yelp(url)
  return parse_last_seg 'yelp', url
end

def parse_citysearch(url)
  match = url.match /profile\/([^\/]+)/
  if not match.nil?
    return parse_result 'citysearch', match[1]
  end
end

def parse_yellowpages(url)
  match = url.match /info-(\d+)/
  if not match.nil?
    return parse_result 'yellowpages', match[1]
  end
end

def parse_locationary(url)
  match = url.match /(p\d+)\.jsp/
  if not match.nil?
    return parse_result 'locationary', match[1]
  end
end


def parse_url(url)
  case
    when url.match(/yahoo/)
      parse_yahoo url
    when url.match(/twitter/)
      parse_twitter url
    when url.match(/foursquare/)
      parse_foursquare url
    when url.match(/yelp/)
      parse_yelp url
    when url.match(/citysearch/)
      parse_citysearch url
    when url.match(/yellowpages/)
      parse_yellowpages url
    when url.match(/locationary/)
      parse_locationary url
  end
end

STDIN.each_line do |line|
  json = JSON.parse line
  uuid = json["uuid"]
  urls = json["urls"]
  ids = {}
  urls.each do |url|
    parsed_url = parse_url url["url"]
    next if parsed_url.nil?
    domain = parsed_url[:domain]
    id = parsed_url[:id]
    ids[domain] = {} if ids[domain].nil?
    ids[domain][id] = url["name"]
  end

  output = {
    :uuid => uuid,
    :ids => ids
  }
  puts JSON.generate(output)
end
