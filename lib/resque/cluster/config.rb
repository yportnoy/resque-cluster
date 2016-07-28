require 'resque/cluster/config/file'
require 'resque/cluster/config/verifier'

module Resque
  class Cluster
    # Config is a global and local configuration of a member of a resque pool cluster
    class Config
      extend Forwardable

      attr_reader :configs, :local_config, :global_config, :verifier, :version_git_hash

      delegate :verified? => :verifier

      def initialize(local_config_path, global_config_path)
        @local_config  = Config::File.new(local_config_path)
        @global_config = global_config_path.nil? ? @local_config : Config::File.new(global_config_path)

        @configs = []
        @configs << local_config
        @configs << global_config unless global_config.expand_path == local_config.expand_path

        @verifier         = Verifier.new(configs)
        @version_git_hash = config_version
      end

      def gru_format
        return {} unless verified?

        {
          manage_worker_heartbeats: true,
          host_maximums:            local_config.contents,
          client_settings:          Resque.redis.client.options,
          cluster_name:             Cluster.config[:cluster_name],
          environment_name:         Cluster.config[:environment],
          cluster_maximums:         global_config["global_maximums"] || global_config.contents,
          rebalance_flag:           global_config["rebalance_cluster"] || false,
          max_workers_per_host:     global_config["max_workers_per_host"] || nil,
          presume_host_dead_after:  global_config["presume_dead_after"] || 120,
          version_hash:             version_git_hash
        }
      end

      def errors
        configs.map { |config| config.errors.map { |error| "#{config}: #{error}" } }.flatten
      end

      def warnings
        @warnings ||= []
      end

      def log_warnings
        warnings.each do |warning|
          puts warning
        end
      end

      def log_errors
        errors.each do |error|
          puts error
        end
      end

      private

      def config_version
        return unless verified?

        directory_name = global_config.dirname

        if directory_name.exist?
          output = Dir.chdir(directory_name) { `git rev-parse --verify HEAD`.chomp }

          if $?.success?
            @version_git_hash = output
          else
            @warnings << "Your config directory: #{directory_name} is not a git repo. Your configuration will not be versioned"
          end
        end
      end
    end
  end
end
