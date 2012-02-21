require "minitest/autorun"
require "./lib/logmixer"
require "./test/minitest_helper.rb"

class TestIO < MiniTest::Unit::TestCase
  def test_unparse
    assert_equal "test", {test: true}.unparse
  end

  def test_parse
    assert_equal({test: true}, "test".parse)
  end
end

class TestIO < MiniTest::Unit::TestCase
  def setup
    @l = LogMixer.new
    @l.filter(:all)
    @l.send(:all) { |log| @l.write :out, log.unparse }
  end

  def teardown
    @l.close
  end

  def test_input
    io = @l.output :out, StringIO.new

    @l.input :tcp, ["nc", "-l", "6969"]
    IO.popen(["nc", "127.0.0.1", "6969"], "w+") { |io| io.puts "test" }

    io.rewind
    assert_equal "test\n", io.readpartial(64)
  end

  def test_output_file
    io = @l.output :out, "log/test", mode: "w+"
    @l.log(test: true)

    io.rewind
    assert_equal "test\n", io.read
  end

  def test_output_io
    io = @l.output :out, StringIO.new
    @l.log(test: true)

    io.rewind
    assert_equal "test\n", io.read
  end

  def test_output_popen
    io = @l.output :out, ["cat"], mode: "w+"
    @l.log(test: true)

    assert_equal "test\n", io.readpartial(64)
  end
end

class TestFilter < MiniTest::Unit::TestCase
  def setup
    @l = LogMixer.new
  end

  def teardown
    @l.close
  end

  def test_empty
    @l.log(test: true)
    assert_equal({}, @l.filters)
  end

  def test_copy
    @l.filter :all
    @l.log(test: true)

    assert_equal([{ :test => true }], @l.filters[:all][:buffer])
  end
end