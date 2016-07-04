module Resque
  class Cluster
    # Config is a global and local configuration of a member of a resque pool cluster
    class Config
      attr_reader :local, :global, :errors, :warnings, :version_git_hash

      def initialize(local_config_path, global_config_path)
        @errors = []
        @warnings = []

        global_config_path = local_config_path if global_config_path.empty?
        @global = try_to_parse_config(global_config_path)
        @local = try_to_parse_config(local_config_path)

        config_version(global_config_path)
      end

      def verified?
        @errors.empty?
      end

      def gru_format
        return {} unless verified?
        {
          cluster_maximums:         @global["global_maximums"] || @global,
          host_maximums:            @local,
          client_settings:          Resque.redis.client.options,
          rebalance_flag:           @global["rebalance_cluster"] || false,
          max_workers_per_host:     @global["max_workers_per_host"] || nil,
          cluster_name:             Cluster.config[:cluster_name],
          environment_name:         Cluster.config[:environment],
          presume_host_dead_after:  @global["presume_dead_after"] || 120,
          manage_worker_heartbeats: true,
          version_hash:             @version_git_hash
        }
      end

      def log_warnings
        @warnings.each do |warning|
          puts warning
        end
      end

      def log_errors
        @errors.each do |error|
          puts error
        end
      end

      private

      def config_version(global_config_path)
        return unless verified?
        directory_name = File.dirname(global_config_path)
        if Dir.exists?(directory_name)
          output = `cd #{directory_name}; git rev-parse --verify HEAD; echo $?`.split
          if output.last == "0"
            @version_git_hash = output.first
          else
            @warnings << "Your config directory: #{directory_name} is not a git repo. Your configuration will not be versioned"
          end
        else
          @errors << "Cannot access #{directory_name} to record a git version hash"
        end
      end

      def try_to_parse_config(config_path)
        config = {}

        # File at path doesn't exist
        if !config_path || !File.exist?(config_path)
          @errors << "Configuration file at '#{config_path}' doesn't exist"
        else
          # try to parse the file provided
          begin
            config = YAML.load(ERB.new(IO.read(config_path)).result)
          rescue
            @errors << "Configuration file at '#{config_path}' is not a valid YAML file"
          end
        end

        return config
      end

    end
  end
end
