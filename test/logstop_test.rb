require_relative "test_helper"

class LogstopTest < Minitest::Test
  def test_email
    assert_filtered "test@test.com"
    assert_filtered "TEST@test.com"
  end

  def test_phone
    assert_filtered "555-555-5555"
    assert_filtered "555 555 5555"
    assert_filtered "555.555.5555"
    refute_filtered "5555555555"
  end

  def test_credit_card
    assert_filtered "4242-4242-4242-4242"
    assert_filtered "4242 4242 4242 4242"
    assert_filtered "4242424242424242"
  end

  def test_ssn
    assert_filtered "123-45-6789"
    assert_filtered "123 45 6789"
    refute_filtered "123456789"
  end

  def test_ip
    refute_filtered "127.0.0.1"
    assert_filtered "127.0.0.1", ip: true
  end

  def test_url_password
    assert_filtered "https://user:pass@host", expected: "https://user:[FILTERED]@host"
    assert_filtered "https://user:pass@host.com", expected: "https://user:[FILTERED]@host.com"
  end

  def test_scrub
    assert_equal "[FILTERED]", Logstop.scrub("test@test.com")
  end

  def test_scrub_with_key
    assert_equal 'Started GET "/" for 131.76.35.185 at 2018-11-27 14:09:23 +0100',
                 Logstop.scrub('Started GET "/" for 8.9.10.42 at 2018-11-27 14:09:23 +0100', ip: true, key: "1234567890")
  end

  def test_scrub_nil
    assert_equal "", Logstop.scrub(nil)
  end

  def test_multiple
    assert_filtered "test@test.com test2@test.com 123-45-6789", expected: "[FILTERED] [FILTERED] [FILTERED]"
  end

  def test_tagged_logging
    str = StringIO.new
    logger = ActiveSupport::Logger.new(str)
    logger = ActiveSupport::TaggedLogging.new(logger)
    Logstop.guard(logger)
    logger.tagged("Ruby") do
      logger.info "begin test@test.com end"
    end
    assert_equal "[Ruby] begin [FILTERED] end\n", str.string
  end

  def test_extra_rules
    assert_filtered "hello", extra_rules: [/hello/, /goodbye/]
    assert_filtered "goodbye", extra_rules: [/hello/, /goodbye/]
  end

  private

  def log(msg, **options)
    str = StringIO.new
    logger = Logger.new(str)
    Logstop.guard(logger, **options)
    logger.info "begin #{msg} end"
    str.string.split(" : ", 2)[-1]
  end

  def assert_filtered(msg, expected: "[FILTERED]", **options)
    assert_equal "begin #{expected} end\n", log(msg, **options)
  end

  def refute_filtered(msg, **options)
    assert_filtered msg, expected: msg, **options
  end
end
