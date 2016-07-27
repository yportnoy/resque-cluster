require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

module Resque
  RSpec.describe Cluster::Config::Verifier do
    let(:valid_local_config)  { Cluster::Config::File.new(support_dir + 'valid_local_config.yml') }
    let(:valid_global_config) { Cluster::Config::File.new(support_dir + 'valid_global_config.yml') }
    let(:broken_yaml_config)  { Cluster::Config::File.new(support_dir + 'broken_yaml_config.yml') }
    let(:non_hash_config)     { Cluster::Config::File.new(support_dir + 'non_hash_config.yml') }
    let(:empty_config)        { Cluster::Config::File.new(support_dir + 'empty_config.yml') }
    let(:missing_config)      { Cluster::Config::File.new(support_dir + 'missing') }

    subject { Cluster::Config::Verifier.new(configs) }

    shared_examples_for 'valid config' do
      it 'verifies' do
        expect(subject).to be_verified
      end
    end

    shared_examples_for 'invalid config' do
      it "doesn't verify" do
        expect(subject).not_to be_verified
      end
    end

    context 'with valid configs' do
      let(:configs) { [valid_local_config, valid_global_config] }

      it_behaves_like 'valid config'
    end

    context 'with a single config file' do
      let(:configs) { [valid_local_config] }

      it_behaves_like 'valid config'
    end

    context 'with a missing config' do
      let(:configs) { [missing_config] }

      it_behaves_like 'invalid config'

      it 'reports the error' do
        subject.verified?

        expect(subject.configs.flat_map(&:errors)).to include("Configuration file doesn't exist")
      end
    end

    context 'with a non-hash config' do
      let(:configs) { [non_hash_config] }

      it_behaves_like 'invalid config'

      it 'reports the error' do
        subject.verified?

        expect(subject.configs.flat_map(&:errors)).to include("Parsed config as invalid type: expected Hash, got FalseClass")
      end
    end

    context 'with an empty config' do
      let(:configs) { [empty_config] }

      it_behaves_like 'invalid config'

      it 'reports the error' do
        subject.verified?

        expect(subject.configs.flat_map(&:errors)).to include("Config file is empty")
      end
    end

    context 'with broken YAML' do
      let(:configs) { [broken_yaml_config] }

      it_behaves_like 'invalid config'

      it 'reports the error' do
        subject.verified?

        expect(subject.configs.flat_map(&:errors)).to include('(<unknown>): did not find expected comment or line break while scanning a block scalar at line 1 column 1')
      end
    end
  end
end
