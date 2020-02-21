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
    assert_equal(
      ['google.com', 'raketaapp2.com', '42istheansweryouneed.com'],
      subject.map { |el| el[0] }
    )
  end

  def test_checks_status
    assert_equal(
      [200, 502, 502],
      subject.map { |el| el[1] } #values.map { |result| result[:status] }
    )
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
