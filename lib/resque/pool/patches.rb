require 'resque/cluster'

module Resque
  # Resque Pool monkey patched methods for resque-pool
  class Pool
    # add the running pool to distributed pool in order to manipulate it
    def self.run
      if GC.respond_to?(:copy_on_write_friendly=)
        GC.copy_on_write_friendly = true
      end
      pool_config = Resque::Cluster.config ? {} : choose_config_file
      started_pool = Resque::Pool.new(pool_config).start
      Resque::Cluster.init(started_pool) if Resque::Cluster.config
      started_pool.join
      Resque::Cluster.member.unregister if Resque::Cluster.member
    end

    # performed inside the run loop, must check for any distributed pool updates
    original_maintain_worker_count = instance_method(:maintain_worker_count)
    define_method(:maintain_worker_count) do
      cluster_update
      original_maintain_worker_count.bind(self).call
    end

    def premature_quit
      log "Quiting ..."
      Process.kill(:QUIT, Process.pid)
    end

    def cluster_update
      Resque::Cluster.member.perform if Resque::Cluster.member
    end

    def adjust_worker_counts(worker, number)
      over_adjustment = ''
      if @config[worker].to_i + number < 0
        over_adjustment = "#{worker}:#{@config[worker].to_i + number}"
        @config[worker] = 0
      else
        @config[worker] = @config[worker].to_i + number
      end
      over_adjustment
    end
  end
end
