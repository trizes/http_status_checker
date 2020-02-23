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
  REQUEST_ERROR = 502

  attr_reader :csv_file, :websites, :statuses

  def process
    read_websites
    read_statuses
    statuses
  end

  private

  def read_websites
    CSV.foreach(csv_file, headers: true) do |row|
      websites.push(row['URL'])
    end
  end

  def read_statuses
    websites.each_with_index do |website, index|
      start_time = Time.now

      status = check_status(website)
      puts "#{index}. #{website}: #{status}"

      statuses.push(
        [
          website, status, (Time.now - start_time).round(2)
        ]
      )
    end
  end

  def check_status(url, limit = REDIRECT_LIMIT)
    return REQUEST_ERROR if limit.zero?

    case response = fetcher(url)
    when Net::HTTPSuccess
      response.code.to_i
    when Net::HTTPRedirection
      check_status(response['location'], limit - 1)
    else
      REQUEST_ERROR
    end
  end

  def fetcher(url)
    HttpFetch.new(url).process
  end
end

class HttpFetch
  def initialize(url)
    @uri = Addressable::URI.heuristic_parse(url)
  end

  # def process
  #   request = HTTPClient.head_async(@uri)
  # end

  def process
    Net::HTTP.start(
      @uri.host, @uri.port, use_ssl: true, read_timeout: 10
    ) { |http| http.request_head(@uri) }
  rescue SocketError, Errno::ECONNREFUSED, Net::ReadTimeout, Net::OpenTimeout,
         OpenSSL::SSL::SSLError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
         Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError
  end
end

unless ENV['RACK_ENV'] == 'test'
  HttpChecker.new(ARGV).process.each do |item|
    print item
    puts
  end
end
