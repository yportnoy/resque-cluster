require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

RSpec.describe Resque::Cluster::Member do
  before :all do
    @redis = Redis.new

    Resque::Cluster.config = {
      cluster_name: 'unit-test-cluster',
      environment: 'unit-test',
      config_path: File.expand_path(File.dirname(__FILE__) + '/../config.yml'),
    }
    @pool = Resque::Pool.new({})
    @member = Resque::Cluster.init(@pool)
  end

  after :all do
    Resque::Cluster.member
    Resque::Cluster.config = nil
    Resque::Cluster.member = nil
  end

  context '#check_for_worker_count_adjustment' do
    before :all do
      @redis.hset("GRU:unit-test:unit-test-cluster:global:max_workers","bar",2)
      @redis.hset("GRU:unit-test:unit-test-cluster:#{HOSTNAME}:max_workers","bar",2)
      @redis.hset("GRU:unit-test:unit-test-cluster:global:workers_running","bar",0)
      @redis.hset("GRU:unit-test:unit-test-cluster:#{HOSTNAME}:workers_running","bar",0)
    end

    it 'adjust worker counts if an adjustment exists on the local command queue' do
      2.times do
        @member.check_for_worker_count_adjustment
        expect(@redis.hget("GRU:unit-test:unit-test-cluster:#{HOSTNAME}:workers_running", 'foo')).to eq '1'
        expect(@redis.hget("GRU:unit-test:unit-test-cluster:#{HOSTNAME}:workers_running", 'bar')).to eq '2'
        expect(@member.pool.config['foo']).to eq(1)
        expect(@member.pool.config['bar']).to eq(2)
      end
    end
  end

  after :all do
    @member.unregister
    @redis.del("GRU:unit-test:unit-test-cluster:global:max_workers")
    @redis.del("GRU:unit-test:unit-test-cluster:global:workers_running")
    @redis.del("GRU:unit-test:unit-test-cluster:heartbeats")
  end

end
