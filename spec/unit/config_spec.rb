require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

RSpec.describe Resque::Cluster::Config do
  let(:redis) { Resque.redis }

  before do
    Resque::Cluster.config = {
      cluster_name: 'unit-test-cluster',
      environment: 'unit-test'
    }
  end

  describe "with valid config files" do
    let(:local_config_path)  { File.expand_path(File.dirname(__FILE__) + '/../local_config.yml') }
    let(:global_config_path) { File.expand_path(File.dirname(__FILE__) + '/../global_config.yml') }
    let(:config)             { Resque::Cluster::Config.new(local_config_path, global_config_path) }

    let(:correct_hash) do
      {
        cluster_maximums:         { 'foo' => 2, 'bar' => 50, "foo,bar,baz" => 1 },
        host_maximums:            { 'foo' => 1, 'bar' => 9, "foo,bar,baz" => 1 },
        client_settings:          redis.client.options,
        rebalance_flag:           false,
        presume_host_dead_after:  120,
        max_workers_per_host:     nil,
        cluster_name:             "unit-test-cluster",
        environment_name:         "unit-test",
        manage_worker_heartbeats: true,
        version_hash:             `git rev-parse --verify HEAD`.strip
      }
    end

    it "should be verified" do
      expect(config.verified?).to eql(true)
    end

    it "config should have no warnings or errors" do
      expect(config.errors.count).to eql(0)
      expect(config.warnings.count).to eql(0)
    end

    it "gru_format should return a correct hash" do
      expect(config.gru_format).to eql(correct_hash)
    end

    it "git_version_hash should be set" do
      expect(config.version_git_hash).to eql(`git rev-parse --verify HEAD`.strip)
    end
  end

  describe "with invalid config file" do
    let(:local_config_path)  { File.expand_path(File.dirname(__FILE__) + '/../local_configuration.yml') }
    let(:global_config_path) { File.expand_path(File.dirname(__FILE__) + '/../../README.rdoc') }
    let(:config)             { Resque::Cluster::Config.new(local_config_path, global_config_path) }
    let(:correct_hash)       { {} }

    it "should not be verified" do
      expect(config.verified?).to eql(false)
    end

    it "config should have no warnings but 2 errors" do
      expect(config.errors.count).to eql(1)
      expect(config.warnings.count).to eql(0)
      expect(config.errors).to contain_exactly(
        "#{local_config_path}: Configuration file doesn't exist")
    end

    it "gru_format should return a an empty hash" do
      expect(config.gru_format).to eql(correct_hash)
    end

    it "git_version_hash should not be set" do
      expect(config.version_git_hash).to be_nil
    end
  end

end
