class LogMixer
  def initialize
    @channels = {}
    @filters  = {}
    @mtx      = Mutex.new
  end

  def log(*datas)
    data = datas.inject(:merge)
    @channels.each do |id, io|
      io.puts data.unparse
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
  end

  def send(ids, period=nil, &blk)
  end

  def receive(ids, period=nil, &blk)
  end

  def write(id, str)
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