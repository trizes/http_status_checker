require 'addressable/uri'
require 'csv'
require 'net/http'
require 'resolv'
require 'resolv-replace'

class HttpChecker
  def initialize(args)
    @csv_file = args[0]
    @websites = []
    @statuses = []
    @threads = []
  end

  WEBSITES_PER_THREAD = 50

  attr_reader :csv_file, :websites, :statuses, :threads

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

  def create_thread_per_group(group)
    Thread.new do
      group.each do |website|
        request = HeadRequest.new(website)

        log_results(request.process)
      end
    end
  end

  def log_results(result)
    print result, "\n"

    statuses.push(result)
  end

  def read_statuses
    websites.each_slice(batch_size) do |group|
      threads.push(create_thread_per_group(group))
    end

    threads.each(&:join)
  end

  def batch_size
    (websites.length / WEBSITES_PER_THREAD.to_f).ceil
  end
end

class HeadRequest
  def initialize(website)
    @website = website
    @start_time = Time.now
    @limit = REDIRECT_LIMIT
  end

  REDIRECT_LIMIT = 10
  REDIRECT_ERROR = 308

  attr_reader :website, :start_time, :end_time, :code, :location

  def process
    return error(REDIRECT_ERROR) if @limit.zero?

    FetchHead.new(self).process

    if location
      @limit -= 1
      process
    else
      finish
    end
  end

  def finish
    @end_time = Time.now
    result
  end

  def duration
    (@end_time - @start_time).round(2)
  end

  def response(response)
    @code = response.code.to_i
    @location = response['location']
  end

  def error(error)
    @code = error
    finish
  end

  def uri
    Addressable::URI.heuristic_parse(@location || @website)
  end

  def result
    [website, code, duration]
  end
end

class FetchHead
  def initialize(request)
    @request = request
    @uri = request.uri
  end

  USER_AGENT = <<~UANAME.freeze
    Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 \
    (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36
  UANAME
  REQUEST_ERROR = 502
  TIMEOUT = 10

  attr_reader :request, :uri

  def opts
    {
      use_ssl: true,
      open_timeout: TIMEOUT,
      read_timeout: TIMEOUT,
      ssl_timeout: TIMEOUT,
      'User-Agent': USER_AGENT
    }
  end

  def process
    response = Net::HTTP.start(
      uri.host, uri.port, opts
    ) { |http| http.request_head(uri) }

    request.response(response)
  rescue SocketError, Errno::ECONNREFUSED, Net::ReadTimeout, Net::OpenTimeout,
         OpenSSL::SSL::SSLError, Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
         Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError, ArgumentError
    request.error(REQUEST_ERROR)
  end
end

HttpChecker.new(ARGV).process unless ENV['RACK_ENV'] == 'test'
