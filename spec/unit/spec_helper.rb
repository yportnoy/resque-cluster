gem 'resque-pool'
require 'pry'
require 'resque/pool/cli'
require 'rspec'
require 'socket'

$LOAD_PATH << File.expand_path('lib/resque/*', File.dirname(__FILE__))
$LOAD_PATH << File.expand_path('lib/resque/pool/*', File.dirname(__FILE__))

require 'resque/cluster'
require 'resque/pool/patches'

@@hostname = Socket.gethostname
