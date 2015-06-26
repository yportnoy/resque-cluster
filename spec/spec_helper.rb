gem 'resque-pool'
require 'pry'
require 'resque/pool/cli'
require 'rspec'

$LOAD_PATH << File.expand_path('lib/resque/*', File.dirname(__FILE__))
$LOAD_PATH << File.expand_path('lib/resque/pool/*', File.dirname(__FILE__))

require 'resque/distributed_pool'
require 'resque/pool/patches'
