require "minitest/autorun"
require "./lib/logmixer"
require "./test/minitest_helper.rb"

class TestParser < MiniTest::Unit::TestCase
  def test_parse_tags
    data = { test: true, exec: true }
    assert_equal "test exec", data.unparse
    assert_equal data, data.unparse.parse
  end

  def test_parse_numbers
    data = { elapsed: 12.000000, __time: 0 }
    assert_equal "elapsed=12.000 __time=0", data.unparse
    assert_equal data, data.unparse.parse
  end

  def test_parse_strings
    data = { s1: 'echo \'hello\' "world"', s2: "hello world", s3: "slasher\\" }
    assert_equal "s1='echo \\'hello\\' \"world\"' s2='hello world' s3='slasher\\\\'", data.unparse
    assert_equal data, data.unparse.parse
  end
end

class TestIO < MiniTest::Unit::TestCase
  def setup
    @l = LogMixer.new
    @l.filter(:all)
    @l.send(:all) { |log| @l.write :out, log.unparse }

    @data = { test: true, __time: 0 }
  end

  def teardown
    @l.close
  end

  def test_input
    io = @l.output :out, StringIO.new

    @l.input :tcp, ["nc", "-l", "6969"]
    IO.popen(["nc", "127.0.0.1", "6969"], "w+") { |io| io.puts "test __time=0" }

    io.rewind
    assert_equal "test __time=0\n", io.readpartial(64)
  end

  def test_output_file
    io = @l.output :out, "log/test", mode: "w+"
    @l.log @data

    io.rewind
    assert_equal "test __time=0\n", io.read
  end

  def test_output_io
    io = @l.output :out, StringIO.new
    @l.log @data

    io.rewind
    assert_equal "test __time=0\n", io.read
  end

  def test_output_popen
    io = @l.output :out, ["cat"], mode: "w+"
    @l.log @data

    assert_equal "test __time=0\n", io.readpartial(64)
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

    data = { test: true, __time: 0 }
    @l.log data

    assert_equal([data], @l.filters[:all][:buffer])
  end

  def test_filter
    @l.filter :exceptions do |log|
      log[:exception]
    end

    data = { exception: true, __time: 0 }
    @l.log data
    @l.log(test: true)

    assert_equal([data], @l.filters[:exceptions][:buffer])
  end

  def test_filter_match
    @l.filter :completed do |log|
      log.match(exec: true, at: /finish|error/)
    end

    @l.log(exec: true, at: :start)
    @l.log(exec: true, at: :finish)
    @l.log(exec: true, at: :start)
    @l.log(exec: true, at: :error)

    assert_equal 2, @l.filters[:completed][:buffer].length
  end

  def test_filter_reduce
    @l.filter :execs_per_min, 60 do |acc, log|
      next unless log.match(exec: true, at: :start)
      acc[:execs_per_min] = true
      acc[:num] ||= 0
      acc[:num]  += 1
      acc
    end

    @l.log(exec: true, at: :start,   __time: 0)
    @l.log(exec: true, at: :finish,  __time: 1)
    @l.log(tick: true,               __time: 1)
    @l.log(exec: true, at: :start,   __time: 2)
    @l.log(exec: true, at: :error,   __time: 3)
    @l.log(exec: true, at: :start,   __time: 60)
    @l.log(exec: true, at: :finish,  __time: 61)

    assert_equal [
      { execs_per_min: true, num: 2, __time: 2,  __bin: 0 },
      { execs_per_min: true, num: 1, __time: 60, __bin: 1 }
    ], @l.filters[:execs_per_min][:buffer]
  end
end