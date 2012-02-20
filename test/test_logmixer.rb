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
    io = @l.output :string, StringIO.new

    @l.input :tcp, ["nc", "-l", "6969"]
    IO.popen(["nc", "127.0.0.1", "6969"], "w+") { |io| io.puts "test" }

    io.rewind
    assert_equal "[\"test\\n\"]\n", io.readpartial(64)
  end

  def test_output_file
    io = @l.output :messages, "log/test", mode: "w+"
    @l.log(test: true)

    io.rewind
    assert_equal "[{:test=>true}]\n", io.read
  end

  def test_output_io
    io = @l.output :string, StringIO.new
    @l.log(test: true)

    io.rewind
    assert_equal "[{:test=>true}]\n", io.read
  end

  def test_output_popen
    io = @l.output :cat, ["cat"], mode: "w+"
    @l.log(test: true)

    assert_equal "[{:test=>true}]\n", io.readpartial(64)
  end
end