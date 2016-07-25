module Resque
  class Cluster
    class ConfigVerifier
      attr_accessor :local_config_path, :global_config_path,

      def initialize(global_config_path, local_config_path = nil)
        @local_config_path = global_config_path if local_config_path.nil?
      end

      def verify
        config_files_exist? &&
        configs_are_yaml_parsable? &&
        configs_are_valid?
      end

      private

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

        def config_files_exist?
          file_exists? (@local_config_path) &&
          file_exists? (@global_config_path)
        end

        def file_exists? (config_path)
          if !config_path
            raise ConfigPathIsRequired
          elsif !File.exist?(config_path)
            raise ConfigFileDoesNotExist
          else
            true
          end
        end

        def configs_are_yaml_parsable?
          YAML.load(ERB.new(IO.read(@global_config_path)).result)
          YAML.load(ERB.new(IO.read(@local_config_path)).result)
          true
        end

        def configs_are_valid?
          true
        end

    end
  end
end
