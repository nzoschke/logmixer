class LogMixer
  attr_reader :filters

  def initialize
    @channels = {}
    @filters  = {}
    @sends    = {}

    @mtx      = Mutex.new
  end

  def log(*datas)
    data = datas.inject(:merge)

    @filters.each do |id, opts|
      buffer = opts[:buffer]
      block  = opts[:block]

      if !block
        buffer << data
      end

      next if !@sends[id]

      @sends[id].each do |opts|
        cond    = opts[:cond]
        blk     = opts[:blk]

        args = [[], [buffer.last], [buffer.last, buffer]]
        blk.call(*args[blk.arity]) if cond.call(*args[cond.arity])
      end
    end
  end

  def input(id, dev, opts={})
    # register IO object and spawn threaded reader
    io = output(id, dev, opts.merge(mode: "r"))

    Thread.new do
      log io.readline.parse while true
    end

    io
  end

  def output(id, dev, opts={})
    if dev.is_a? Array
      dev = IO.popen(dev, mode=opts[:mode] || "w")
    elsif dev.is_a? String
      dev = File.open(dev, mode=opts[:mode] || "a")
    end
    dev.sync = true
    @channels[id] = dev
  end

  def filter(id, period=nil, &blk)
    @filters[id] = { period: period, blk: blk, buffer: [] }
  end

  def send(ids, cond=nil, &blk)
    ids = [ids] if !ids.is_a?(Array)
    cond ||= lambda { true }

    ids.each do |id|
      @sends[id] ||= []
      @sends[id] << { cond: cond, blk: blk }
    end
  end

  def receive(ids, period=nil, &blk)
  end

  def write(id, str)
    @channels[id].puts str
  end

  def close
    @channels.each do |id, io|
      next if [STDERR, STDOUT].include? io

      if pid = io.pid
        Process.kill "TERM", pid
        Process.wait pid
      end
      io.close
    end
  end
end

class Hash
  def unparse
    self.map do |(k, v)|
      if (v == true)
        k.to_s
      elsif (v == false)
        "#{k}=false"
      elsif (v.is_a?(String) && v.include?("\""))
        "#{k}='#{v}'"
      elsif (v.is_a?(String) && (v !~ /^[a-zA-Z0-9\:\.\-\_]+$/))
        "#{k}=\"#{v}\""
      elsif (v.is_a?(String) || v.is_a?(Symbol))
        "#{k}=#{v}"
      elsif v.is_a?(Float)
        "#{k}=#{format("%.3f", v)}"
      elsif v.is_a?(Numeric) || v.is_a?(Class) || v.is_a?(Module)
        "#{k}=#{v}"
      end
    end.compact.join(" ")
  end
end

class String
  def parse
    data = {}
    self.split.each { |w| data[w.to_sym] = true }
    data
  end
end