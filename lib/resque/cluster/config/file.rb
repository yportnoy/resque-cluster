module Resque
  class Cluster
    class Config
      class File < Pathname
        extend Forwardable

        delegate :[] => :contents

        def exist?
          super.tap { |exists| errors << "Configuration file doesn't exist" unless exists }
        end

        def valid?
          if contents.is_a?(Hash)
            errors << "Config file is empty" unless contents.any?
          else
            errors << "Parsed config as invalid type: expected Hash, got #{contents.class}"
          end

          contents.is_a?(Hash) && contents.any? && complete_worker_config?
        end

        def errors
          @errors ||= Set.new
        end

        def contents
          @contents ||=
            begin
              YAML.load(ERB.new(self.read).result)
            rescue => e
              errors << e.message

              nil
            end
        end

        private

        def complete_worker_config?
          contents['workers'].all? { |_, maximums| maximums.key?('local') && maximums.key?('global') }.tap do |complete|
            errors << "Every worker configuration must contain a local and a global maximum." unless complete
          end
        end
      end
    end
  end
end
