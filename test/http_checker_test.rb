ENV['RACK_ENV'] = 'test'

require 'test/unit'
require_relative '../lib/http_checker'

class HttpCheckerTest < Test::Unit::TestCase
  def subject
    HttpChecker.new(stub_csv).process
  end

  def stub_csv
    ['websites.csv']
  end

  def test_checks_websites
    results = subject.map { |el| el[0] }

    ['google.com', 'raketaapp2.com', '42istheansweryouneed.com'].each do |website|
      assert(results.include?(website))
    end
  end

  def test_checks_status
    results = subject.map { |el| el[1] }

    [200, 502].each do |status|
      assert(results.include?(status))
    end
  end

  def test_measures_runtime
    times = subject.map { |el| el[2] }
    times.each do |time|
      assert_kind_of(
        Float,
        time
      )
    end
  end
end
