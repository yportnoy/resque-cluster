require 'socket'
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

RSpec.describe Resque::DistributedPool::Member do
  before :all do
    @redis = Redis.new

    Resque::DistributedPool.config = {
      cluster_name: 'test-cluster',
      environment: 'test',
      local_config_path: 'spec/local_config.yml',
      global_config_path: 'spec/global_config.yml',
      rebalance: true }
    @pool = Resque::Pool.new({"foo" => 1})
    @member = Resque::DistributedPool.init(@pool)
    @hostname = Socket.gethostname
  end

  after :all do
    Resque::DistributedPool.member.unregister
    Resque::DistributedPool.config = nil
    Resque::DistributedPool.member = nil
  end

  context '#register' do
    before :all do
      @member.register
    end

    it 'pings into redis to let the rest of the cluster know of it' do
      expect(@redis.hget('resque:cluster:test-cluster:test', @hostname)).to_not be_nil
    end
  end

  context '#check_for_worker_count_adjustment' do
    before :all do
      @redis.hset("GRU:global:max_workers","bar",2)
      @redis.hset("GRU:#{@hostname}:max_workers","bar",2)
      @redis.hset("GRU:global:workers_running","bar",0)
      @redis.hset("GRU:#{@hostname}:workers_running","bar",0)
    end

    it 'adjust worker counts if an adjustment exists on the local command queue' do
      2.times do
        @member.check_for_worker_count_adjustment
        expect(@redis.hget("GRU:#{@hostname}:workers_running", 'foo')).to eq '1'
        expect(@redis.hget("GRU:#{@hostname}:workers_running", 'bar')).to eq '2'
        expect(@member.pool.config['foo']).to eq(1)
        expect(@member.pool.config['bar']).to eq(2)
      end
    end
  end

  context '#unregister' do
    before :all do
      @member.unregister
    end

    it 'removes everything about itself from redis' do
      expect(@redis.hget('resque:cluster:test-cluster:test', @hostname)).to be_nil
      expect(@redis.get("resque:cluster:test-cluster:test:#{@hostname}:running_workers")).to be_nil
    end

    it 'moves all the current running workers into the global queue if rebalance_on_termination is set to true' do
      expect(@redis.hget('GRU:global:workers_running', 'bar')).to eq '0'
      expect(@redis.hget('GRU:global:workers_running', 'foo')).to eq '0'
      expect(@redis.hget("GRU:#{@hostname}:workers_running", 'bar')).to eq '0'
      expect(@redis.hget("GRU:#{@hostname}:workers_running", 'foo')).to eq '0'
    end
  end

  after :all do
    @redis.del('cluster:test-cluster:test:command_queue')
    @redis.del("GRU:#{@hostname}:max_workers")
    @redis.del("GRU:#{@hostname}:workers_running")
    @redis.del("GRU:global:max_workers")
    @redis.del("GRU:global:workers_running")
  end

end
