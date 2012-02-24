# LogMixer

LogMixer is a pure Ruby library for logs-as-data parsing, routing, filtering and analysis.

LogMixer borrows concepts from an audio mixing board:

* Input/output channels
* Sends/receive hooks for data on channels
* Simple filters for dropping data
* Advanced filters for analyzing data

Sample usage for logging an event stream and analyzing how many events per second are generated:

```ruby
LM = LogMixer.new

# Input and output 'channels' are Ruby IO objects
LM.output :out,     STDOUT
LM.output :events,  "log/events.log"
LM.input  :tcp,     ["nc", "-l", "6969"]

# 'Filters' are Ruby blocks. A non-true return drops the data.
LM.filter :events do |data|
  !data[:stats]
end

# 'Filters' can also analyze / reduce data
LM.filter :events_per_min, 60 do |acc, data|
  next unless data.match(at: /start/)
  acc[:stats] = true
  acc[:num] ||= 0
  acc[:num]  += 1
  acc
end

# 'Sends' route filtered data to channels
LM.send(:events) { |data| LM.write :events, data.unparse }
LM.send(:stats)  { |data| LM.write :out,    data.unparse }

# 'Receives' route raw data into the pipeline
LM.receive(:tcp) do |msg|
  LM.log msg.strip.parse
end
```