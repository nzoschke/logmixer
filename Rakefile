require "bundler"
Bundler.setup

require "rake/testtask"
Rake::TestTask.new do |t|
  t.pattern = "test/test_*.rb"
  t.ruby_opts << "-rturn"
end
task :default => :test