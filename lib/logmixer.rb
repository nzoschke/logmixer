require "logmixer/version"

module LogMixer
  class LogMixer
    attr_reader :filters

    def initialize
      @channels = {}
      @filters  = {}
      @sends    = {}
      @receives = {}

      @mtx      = Mutex.new
    end

    def log(*datas)
      data = datas.inject(:merge)
      data[:__time] ||= Time.now.to_f

      @filters.each do |id, opts|
        blk     = opts[:blk]
        buffer  = opts[:buffer]
        period  = opts[:period]

        bin = (data[:__time] / period.to_f).floor rescue -1

        acc = buffer.detect { |d| d[:__bin] == bin }        # find accumulator

        args = [[], [data], [acc || { id => true }, data]]
        if new_acc = blk.call(*args[blk.arity])             # update accumulator
          if blk.arity == 2
            buffer << new_acc if acc.nil?                   # append if new accumulator

            new_acc.merge!(
              __time: data[:__time],
              __bin:  bin
            )

            data = nil
            data = buffer[-2] if acc.nil?                   # send previous if new accumulator
          else
            buffer << data
          end

          next if !data
          next if !@sends[id]

          send_args = [[], [data], [buffer, data]]
          @sends[id].each do |opts|
            cond    = opts[:cond]
            blk     = opts[:blk]

            blk.call(*send_args[blk.arity]) if cond.call(*send_args[cond.arity])
          end
        end
      end
    end

    def input(id, dev, opts={})
      # register IO object and spawn threaded reader
      io = output(id, dev, opts.merge(mode: "r"))

      Thread.new do
        while true
          msg =  io.readline.strip

          @receives[id].each do |opts|
            cond    = opts[:cond]
            blk     = opts[:blk]

            blk.call(msg)
          end
        end
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
      blk ||= lambda { true }
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

    def receive(ids, cond=nil, &blk)
      ids = [ids] if !ids.is_a?(Array)
      cond ||= lambda { true }

      ids.each do |id|
        @receives[id] ||= []
        @receives[id] << { cond: cond, blk: blk }
      end
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
end

class Hash
  def match(h)
    return false if keys & h.keys != h.keys

    h.each do |k, v|
      if v.is_a? Regexp
        return false if !v.match(self[k].to_s)
      else
        return false if self[k] != v
      end
    end

    return true
  end

  def unparse
    self.map do |(k, v)|
      if (v == true)
        k.to_s
      elsif (v == false)
        "#{k}=false"
      elsif v.is_a?(String) && v =~ /\\|\"| / # escape and quote val with " or \ or multiple words
        v = v.gsub(/\\|"/) { |c| "\\#{c}" }
        "#{k}=\"#{v}\""
      elsif v.is_a?(Float)
        "#{k}=#{format("%.3f", v)}"
      else
        "#{k}=#{v}"
      end
    end.compact.join(" ")
  end
end

class String
  def parse
    vals  = {}
    s     = self.dup

    patterns = [
      /([^= ]+)="([^"\\]*(\\.[^"\\]*)*)"/,    # key="\"literal\" escaped val"
      /([^= ]+)=([^ =]+)/                     # key=value
    ]
    patterns.each do |p|
      s.scan(p) do |match|
        v = match[1]
        v.gsub!(/\\"/, '"')                   # unescape \"
        v.gsub!(/\\\\/, "\\")                 # unescape \\

        if v.to_i.to_s == v                   # cast value to int or float
          v = v.to_i
        elsif format("%.3f", v.to_f) == v
          v = v.to_f
        end

        vals[match[0]] = v
      end
      s.gsub!(p, "\\1")                       # sub value, leaving keys in order
    end

    # rebuild in-order key: value hash
    s.split.inject({}) do |h, k|
      h[k.to_sym] = vals[k] || true
      h
    end
  end
end