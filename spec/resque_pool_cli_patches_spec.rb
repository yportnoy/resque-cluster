require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'resque/pool/cli_patches'

RSpec.describe Resque::Pool::CLI do
  after :all do
    Resque::DistributedPool.config = nil
    Resque::DistributedPool.member = nil
  end

  context "#run" do
    it "sets up to run resque-pool the standard way if no params are passed in" do
      stub_const("ARGV", [])
      allow(Resque::Pool::CLI).to receive(:start_pool).and_return({ })
      Resque::Pool::CLI.run
      expect(Resque::DistributedPool.config).to be_nil
    end

    it "sets up to run resque-pool the standard way if no cluster params are passed in" do
      stub_const("ARGV", ["-c", "spec/local_config.yml", "-E", "test", "-G", "spec/global_config.yml"])
      allow(Resque::Pool::CLI).to receive(:start_pool).and_return({ })
      Resque::Pool::CLI.run
      expect(Resque::DistributedPool.config).to be_nil
      expect(ENV["RESQUE_POOL_CONFIG"]).to eq("spec/local_config.yml")
      expect(ENV["RESQUE_ENV"]).to eq("test")
    end

    it "sets up to run resque-pool the cluster way if cluster param is passed in" do
      stub_const("ARGV", ["-c", "spec/local_config.yml", "-E", "test", "-C", "test-cluster", "-R", "-G", "spec/global_config.yml"])
      allow(Resque::Pool::CLI).to receive(:start_pool).and_return({ })
      Resque::Pool::CLI.run
      expect(Resque::DistributedPool.config[:cluster_name]).to eq("test-cluster")
      expect(ENV["RESQUE_POOL_CONFIG"]).to eq("spec/local_config.yml")
      expect(ENV["RESQUE_ENV"]).to eq("test")
    end
  end
end