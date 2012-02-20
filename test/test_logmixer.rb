require "minitest/autorun"
require "./lib/logmixer"
require "./test/minitest_helper.rb"

class TestIO < MiniTest::Unit::TestCase
  def setup
    @l = LogMixer.new
  end

  def teardown
    @l.close
  end

  def test_input
  end

  def test_output_file
    path = "log/test"
    @l.output :messages, path, mode: "w"
    @l.log(test: true)

    assert File.exists?(path)
    assert_equal "[{:test=>true}]\n", File.read(path)
  end

  def test_output_io
    @l.output :stdout, STDOUT
    @l.log(test: true)
  end

  def test_output_popen
    @l.output :syslog, ["logger"]
    @l.log(test: true)
  end
end