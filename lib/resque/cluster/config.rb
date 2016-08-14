require 'resque/cluster/config/file'
require 'resque/cluster/config/verifier'

module Resque
  class Cluster
    # Config is a global and local configuration of a member of a resque pool cluster
    class Config
      extend Forwardable

      attr_reader :configs, :config, :global_config, :verifier, :version_git_hash

      def initialize(config_path, global_config_path = nil)
        @config = Config::File.new(config_path)

        @configs = [config]

        if global_config_path
          global_config = Config::File.new(global_config_path)

          if global_config.expand_path != config.expand_path
            @global_config = global_config

            @configs << global_config
          end
        end

        @errors           = Set.new
        @verifier         = Verifier.new(configs)
        @version_git_hash = config_version
      end

      def verified?
        verifier.verified? && complete_worker_config?
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
          rebalance_flag:           rebalance_flag || false,
          max_workers_per_host:     max_workers_per_host || nil,
          presume_host_dead_after:  presume_dead_after || 120,
          version_hash:             version_git_hash
        }
      end

      def errors
        @errors + configs.map { |config| config.errors.map { |error| "#{config}: #{error}" } }.flatten
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

      def complete_worker_config?
        host = host_maximums.delete_if { |_, v| v.nil? }
        cluster = cluster_maximums.delete_if { |_, v| v.nil? }

        (host.keys == cluster.keys).tap do |complete|
          @errors << "Every worker configuration must contain a local and a global maximum." unless complete
        end
      end

      def host_maximums
        case config_type
        when :separate
          config.contents
        when :old
          config.contents.reject do |k, _|
            ['global_maximums', 'presume_dead_after', 'max_workers_per_host', 'rebalance_cluster'].include?(k)
          end
        when :new
          config['workers'].each.with_object({}) do |(pool, maximums), local_maximums|
            local_maximums[pool] = maximums['local']
          end
        end
      end

      def cluster_maximums
        case config_type
        when :separate
          global_config['global_maximums'] || global_config.contents.reject do |k, _|
            ['global_maximums', 'presume_dead_after', 'max_workers_per_host', 'rebalance_cluster'].include?(k)
          end
        when :old
          config['global_maximums']
        when :new
          config['workers'].each.with_object({}) do |(pool, maximums), global_maximums|
            global_maximums[pool] = maximums['global']
          end
        end
      end

      def rebalance_flag
        case config_type
        when :separate
          global_config['rebalance_cluster']
        when :old, :new
          config['rebalance_cluster']
        end
      end

      def max_workers_per_host
        case config_type
        when :separate
          global_config['max_workers_per_host']
        when :old, :new
          config['max_workers_per_host']
        end
      end

      def presume_dead_after
        case config_type
        when :separate
          global_config['presume_dead_after']
        when :old, :new
          config['presume_dead_after']
        end
      end

      def config_type
        @config_type ||=
          if global_config
            :separate
          elsif config['workers']
            :new
          else
            :old
          end
      end

      def config_version
        return unless verified?

        directory_name = config.dirname

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
