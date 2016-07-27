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

          contents.is_a?(Hash) && contents.any?
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
      end
    end
  end
end
