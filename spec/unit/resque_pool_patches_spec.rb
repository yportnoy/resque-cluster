require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

RSpec.describe Resque::Pool do
  after :each do
    Resque::Cluster.member.unregister if Resque::Cluster.member
    Resque::Cluster.config = nil
    Resque::Cluster.member = nil
  end

  context "#run" do
    it "pool config is not empty if running in a non cluster mode after initialization" do
      pool = nil
      ENV['RESQUE_POOL_CONFIG'] = "spec/local_config.yml"
      allow_any_instance_of(Resque::Pool).to receive(:join) {|instance| pool = instance }
      allow_any_instance_of(Resque::Cluster::Member).to receive(:unregister).and_return("")
      Resque::Pool.run
      expect(pool.config['foo']).to eq(1)
    end

    it "pool config is empty if running in a cluster mode after initialization" do
      pool = nil
      ENV['RESQUE_POOL_CONFIG'] = "spec/local_config.yml"
      allow_any_instance_of(Resque::Pool).to receive(:join) {|instance| pool = instance }
      allow_any_instance_of(Resque::Cluster::Member).to receive(:unregister).and_return("")

      Resque::Cluster.config = {:cluster_name=>"test-cluster",
                                        :environment=>"test",
                                        :local_config_path=>"spec/local_config.yml",
                                        :global_config_path=>"spec/global_config.yml",
                                        :rebalance=>true}

      Resque::Pool.run
      expect(pool.config).to be_empty
    end

  end

  context "#maintain_worker_count" do
    it "should adjust current number of workers" do
      pool = nil
      ENV['RESQUE_POOL_CONFIG'] = "spec/local_config.yml"
      allow_any_instance_of(Resque::Pool).to receive(:join) {|instance| pool = instance }
      allow_any_instance_of(Resque::Cluster::Member).to receive(:unregister).and_return("")

      Resque::Cluster.config = {:cluster_name=>"test-cluster",
                                        :environment=>"test",
                                        :local_config_path=>"spec/local_config.yml",
                                        :global_config_path=>"spec/global_config.yml",
                                        :rebalance=>true}

      Resque::Pool.run
      expect(pool.config).to be_empty
      pool.maintain_worker_count
      expect(pool.config['foo']).to eq(1)
      expect(pool.config['bar']).to eq(9)
      expect(pool.config['foo,bar,baz']).to eq(1)
    end
  end

  after :all do
    @redis = Redis.new
    @redis.del("resque:cluster:test-cluster:test")
    @redis.del("resque:cluster:test-cluster:test:perun:running_workers")
    @redis.del("GRU:#{@@hostname}:max_workers")
    @redis.del("GRU:#{@@hostname}:workers_running")
    @redis.del("GRU:global:max_workers")
    @redis.del("GRU:global:workers_running")
  end

end
