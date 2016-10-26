require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

RSpec.describe Resque::Cluster::Config do
  let(:redis) { Resque.redis }

  before do
    config.verified?

    Resque::Cluster.config = {
      cluster_name: 'unit-test-cluster',
      environment: 'unit-test'
    }
  end

  shared_examples_for 'a valid config' do
    it 'is verified' do
      expect(config).to be_verified
    end

    it "gru_format should return a correct hash" do
      expect(config.gru_format).to eql(correct_hash)
    end
  end

  describe 'with a single config file' do
    let(:config) { Resque::Cluster::Config.new(config_path) }
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
        manage_worker_heartbeats: true
      }
    end

    context 'old style' do
      let(:config_path) { support_dir + 'valid_single_old_config.yml' }

      it_behaves_like 'a valid config'

      context 'with a missing local maximum' do
        let(:config) { Resque::Cluster::Config.new(config_path) }
        let(:config_path) { support_dir + 'single_old_missing_local.yml' }

        it 'should not be verified' do
          expect(config).not_to be_verified
        end

        it 'should not be verified' do
          expect(config.errors).to contain_exactly("Every worker configuration must contain a local and a global maximum.")
        end
      end

      context 'with a missing global maximum' do
        let(:config) { Resque::Cluster::Config.new(config_path) }
        let(:config_path) { support_dir + 'single_old_missing_global.yml' }

        it 'should not be verified' do
          expect(config).not_to be_verified
        end

        it 'should not be verified' do
          expect(config.errors).to contain_exactly("Every worker configuration must contain a local and a global maximum.")
        end
      end
    end

    context 'new style' do
      let(:config_path) { support_dir + 'valid_single_new_config.yml' }

      it_behaves_like 'a valid config'

      context 'with a missing local maximum' do
        let(:config) { Resque::Cluster::Config.new(config_path) }
        let(:config_path) { support_dir + 'missing_local_maximum.yml' }

        it 'should not be verified' do
          expect(config).not_to be_verified
        end

        it 'should not be verified' do
          expect(config.errors).to contain_exactly("Every worker configuration must contain a local and a global maximum.")
        end
      end

      context 'with a missing global maximum' do
        let(:config) { Resque::Cluster::Config.new(config_path) }
        let(:config_path) { support_dir + 'missing_global_maximum.yml' }

        it 'should not be verified' do
          expect(config).not_to be_verified
        end

        it 'should not be verified' do
          expect(config.errors).to contain_exactly("Every worker configuration must contain a local and a global maximum.")
        end
      end
    end
  end

  describe 'separate config files' do
    context "with valid config files" do
      let(:config)             { Resque::Cluster::Config.new(local_config_path, global_config_path) }
      let(:local_config_path)  { File.expand_path(File.dirname(__FILE__) + '/../local_config.yml') }
      let(:global_config_path) { File.expand_path(File.dirname(__FILE__) + '/../global_config.yml') }

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
          manage_worker_heartbeats: true
        }
      end

      it_behaves_like 'a valid config'

      it "config should have no warnings or errors" do
        expect(config.errors.count).to eql(0)
        expect(config.warnings.count).to eql(0)
      end
    end

    context 'with a missing local maximum' do
      let(:config)             { Resque::Cluster::Config.new(local_config_path, global_config_path) }
      let(:local_config_path)  { support_dir + 'separate_missing_local.yml' }
      let(:global_config_path) { File.expand_path(File.dirname(__FILE__) + '/../global_config.yml') }

      it 'should not be verified' do
        expect(config).not_to be_verified
      end

      it 'should not be verified' do
        expect(config.errors).to contain_exactly("Every worker configuration must contain a local and a global maximum.")
      end
    end

    context 'with a missing global maximum' do
      let(:config)             { Resque::Cluster::Config.new(local_config_path, global_config_path) }
      let(:local_config_path)  { File.expand_path(File.dirname(__FILE__) + '/../local_config.yml') }
      let(:global_config_path) { support_dir + 'separate_missing_global.yml' }

      it 'should not be verified' do
        expect(config).not_to be_verified
      end

      it 'should not be verified' do
        expect(config.errors).to contain_exactly("Every worker configuration must contain a local and a global maximum.")
      end
    end

    context "with invalid config file" do
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
    end
  end
end
