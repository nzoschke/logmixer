class LogMixer
  def initialize
    @channels = {}
    @filters  = {}
    @mtx      = Mutex.new
  end

  def close
    @channels.each { |id, io| io.close unless [STDERR, STDOUT].include? io }
  end

  def log(*datas)
    @channels.each do |id, io|
      io.puts datas.inspect
    end
  end

  def input(id, dev, opts={})
    # register IO object and spawn threaded reader
    output(id, dev, opts)
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
end