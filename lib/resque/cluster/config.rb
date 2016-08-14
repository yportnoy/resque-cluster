require 'resque/cluster/config/file'

module Resque
  class Cluster
    class Config
      extend Forwardable

      attr_reader :config, :version_git_hash

      delegate :errors => :config

      def initialize(config_path)
        @config           = Config::File.new(config_path)
        @version_git_hash = config_version
      end

      def gru_format
        return {} unless verified?

        {
          manage_worker_heartbeats: true,
          host_maximums:            host_maximums,
          client_settings:          Resque.redis.client.options,
          cluster_name:             Cluster.config[:cluster_name],
          environment_name:         Cluster.config[:environment],
          cluster_maximums:         cluster_maximums,
          rebalance_flag:           config['rebalance_cluster'] || false,
          max_workers_per_host:     config['max_workers_per_host'] || nil,
          presume_host_dead_after:  config['presume_dead_after'] || 120,
          version_hash:             version_git_hash
        }
      end

      def verified?
        config.exist? && config.valid?
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

      def host_maximums
        config['workers'].each.with_object({}) do |(pool, maximums), local_maximums|
          local_maximums[pool] = maximums['local']
        end
      end

      def cluster_maximums
        config['workers'].each.with_object({}) do |(pool, maximums), global_maximums|
          global_maximums[pool] = maximums['global']
        end
      end

      def config_version
        return unless verified?

        directory_name = config.dirname

        if directory_name.exist?
          output = Dir.chdir(directory_name) { `git rev-parse --verify HEAD`.chomp }

          if $?.success?
            output
          else
            @warnings << "Your config directory: #{directory_name} is not a git repo. Your configuration will not be versioned"

            nil
          end
        end
      end
    end
  end
end
