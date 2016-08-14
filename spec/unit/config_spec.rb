require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

RSpec.describe Resque::Cluster::Config do
  let(:redis)  { Resque.redis }
  let(:config) { Resque::Cluster::Config.new(config_path) }

  before do
    Resque::Cluster.config = {
      cluster_name: 'unit-test-cluster',
      environment: 'unit-test'
    }
  end

  describe 'with a valid config file' do
    let(:config_path) { support_dir + 'valid_config.yml' }

    let(:correct_hash) do
      {
        cluster_maximums:         { 'foo' => 2, 'bar' => 50, "foo,bar,baz" => 1 },
        host_maximums:            { 'foo' => 1, 'bar' => 9, "foo,bar,baz" => 1 },
        client_settings:          redis.client.options,
        rebalance_flag:           true,
        presume_host_dead_after:  60,
        max_workers_per_host:     10,
        cluster_name:             "unit-test-cluster",
        environment_name:         "unit-test",
        manage_worker_heartbeats: true,
        version_hash:             `git rev-parse --verify HEAD`.strip
      }
    end

    it 'is verified' do
      expect(config).to be_verified
    end

    it "gru_format should return a correct hash" do
      expect(config.gru_format).to eql(correct_hash)
    end
  end

  describe 'with a missing local maximum' do
    let(:config_path) { support_dir + 'missing_local_maximum.yml' }

    it 'should not be verified' do
      expect(config).not_to be_verified
    end

    it 'should not be verified' do
      expect(config.errors).to contain_exactly("Every worker configuration must contain a local and a global maximum.")
    end
  end

  describe 'with a missing global maximum' do
    let(:config_path) { support_dir + 'missing_global_maximum.yml' }

    it 'should not be verified' do
      expect(config).not_to be_verified
    end

    it 'should not be verified' do
      expect(config.errors).to contain_exactly("Every worker configuration must contain a local and a global maximum.")
    end
  end

  describe "with a missing config file" do
    let(:config_path)  { File.expand_path(File.dirname(__FILE__) + '/../missing.yml') }
    let(:correct_hash) { {} }

    it 'should not be verified' do
      expect(config.verified?).to eql(false)
    end

    it "config should have no warnings and 1 error" do
      expect(config.errors.count).to eql(1)
      expect(config.warnings.count).to eql(0)
      expect(config.errors).to contain_exactly("Configuration file doesn't exist")
    end

    it "gru_format should return a an empty hash" do
      expect(config.gru_format).to eql(correct_hash)
    end

    it "git_version_hash should not be set" do
      expect(config.version_git_hash).to be_nil
    end
  end
end
