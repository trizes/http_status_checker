require 'net/http'
require 'addressable/uri'
require 'csv'

class HttpChecker
  def initialize(args)
    @csv_file = args[0]
    @websites = []
    @statuses = []
  end

  USER_AGENT = <<~UANAME.freeze
    Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
    (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36
  UANAME

  REDIRECT_LIMIT = 10
  DNS_ERROR = 502
  REQUEST_ERROR = 504

  attr_reader :csv_file, :websites, :statuses

  def process
    read_websites
    read_statuses
    statuses
  end

  private

  def read_statuses
    websites.each do |website|
      start_time = Time.now

      statuses.push(
        [
          website, http_fetch(website), (Time.now - start_time).round(2)
        ]
      )
    end
  end

  def parse_link_to_uri(website)
    Addressable::URI.heuristic_parse(website)
  end

  def http_fetch(url, limit = REDIRECT_LIMIT)
    raise REQUEST_ERROR, 'HTTP redirect too deep' if limit.zero?

    uri = parse_link_to_uri(url)

    response = Net::HTTP.start(
      uri.host, uri.port, use_ssl: true
    ) { |http| http.request_head(uri) }

    case response
    when Net::HTTPSuccess     then response.code.to_i
    when Net::HTTPRedirection then http_fetch(response['location'], limit - 1)
    else REQUEST_ERROR
    end
  rescue SocketError
    DNS_ERROR
  end

  def read_websites
    CSV.foreach(csv_file, headers: true) do |row|
      websites << row['URL']
    end
  end
end

unless ENV['RACK_ENV'] == 'test'
  HttpChecker.new(ARGV).process.each do |item|
    print item
    puts
  end
end
