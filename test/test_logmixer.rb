require "minitest/autorun"
require "./lib/logmixer"
require "./test/minitest_helper.rb"

class TestParser < MiniTest::Unit::TestCase
  def test_parse_tags
    # Value true => non key-value encoding
    data = { test: true, exec: true }
    assert_equal "test exec", data.unparse
    assert_equal data.inspect, data.unparse.parse.inspect # order is preserved
  end

  def test_parse_numbers
    # Numeric and Float are encoded and decoded
    data = { elapsed: 12.000000, __time: 0 }
    assert_equal "elapsed=12.000 __time=0", data.unparse
    assert_equal data.inspect, data.unparse.parse.inspect
  end

  def test_parse_strings
    # Strings are all double quoted, with " or \ escaped
    data = { s: "echo 'hello' \"world\"" }
    assert_equal 's="echo \'hello\' \\"world\\""', data.unparse
    assert_equal data.inspect, data.unparse.parse.inspect

    data = { s: "hello world" }
    assert_equal 's="hello world"', data.unparse
    assert_equal data.inspect, data.unparse.parse.inspect

    data = { s: "slasher\\" }
    assert_equal 's="slasher\\\\"', data.unparse
    assert_equal data.inspect, data.unparse.parse.inspect

    # simple value is unquoted
    data = { s: "hi" }
    assert_equal 's=hi', data.unparse
    assert_equal data.inspect, data.unparse.parse.inspect
  end

  def test_parse_constants
    # Non-strings are not single quoted
    data = { s1: :symbol, s2: LogMixer }
    assert_equal "s1=symbol s2=LogMixer", data.unparse
  end
end

class TestIO < MiniTest::Unit::TestCase
  include LogMixer

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
    @l.receive(:tcp) { |msg| @l.write :out, msg }


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
  include LogMixer

  def setup
    @l  = LogMixer.new
    @io = []
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
    @l.send(:execs_per_min) { |data| @io << data }

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

    # bin 1 hasn't been sent yet
    assert_equal @l.filters[:execs_per_min][:buffer][0, 1], @io
  end

  def test_filter_rereduce
    @l1 = LogMixer.new
    @l2 = LogMixer.new
    @l3 = LogMixer.new

    send = lambda { |data| @l3.log data }

    filter = Proc.new do |acc, data|
      next unless data.match(exec: true, at: :start) || data.match(execs_per_min: true)
      acc[:num] ||= 0
      acc[:num]  += data[:num] || 1
      acc
    end

    @l1.filter :execs_per_min, 60, &filter
    @l1.send(:execs_per_min, &send)

    @l2.filter :execs_per_min, 60, &filter
    @l2.send(:execs_per_min, &send)

    @l3.filter :execs_per_min, 60, &filter
    @l3.send(:execs_per_min) { |data| @io << data }

    @l1.log(exec: true, at: :start,   __time: 0)
    @l1.log(exec: true, at: :finish,  __time: 1)
    @l1.log(exec: true, at: :start,   __time: 60)
    @l1.log(exec: true, at: :finish,  __time: 61)
    @l1.log(exec: true, at: :start,   __time: 200) # 'flush' buffer

    @l2.log(exec: true, at: :start,   __time: 10)
    @l2.log(exec: true, at: :finish,  __time: 12)
    @l2.log(exec: true, at: :start,   __time: 125)
    @l2.log(exec: true, at: :finish,  __time: 126)
    @l2.log(exec: true, at: :start,   __time: 200) # 'flush' buffer

    assert_equal 3, @l1.filters[:execs_per_min][:buffer].length
    assert_equal 3, @l2.filters[:execs_per_min][:buffer].length

    buffer = @l3.filters[:execs_per_min][:buffer]
    assert_equal [0, 1, 2], buffer.collect { |d| d[:__bin] }
    assert_equal [2, 1, 1], buffer.collect { |d| d[:num] }

    # bin > 1 hasn't been sent yet
    assert_equal @l3.filters[:execs_per_min][:buffer][0, 2], @io
  end
end