module Resque
  class Cluster
    class Config
      class Verifier
        attr_reader :configs

        def initialize(configs)
          @configs = configs
        end

        def verified?
          configs_exist? && configs_are_valid?
        end

        private

        def configs_exist?
          configs.all?(&:exist?)
        end

        def configs_are_valid?
          configs.all?(&:valid?)
        end
      end
    end
  end
end
