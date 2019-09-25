require 'socket'
require 'gru'

module Resque
  class Cluster
    # Member is a single member of a resque pool cluster
    class Member
      attr_reader :hostname, :pool, :config

      def initialize(started_pool)
        @pool = started_pool
        @config = Config.new(Cluster.config[:local_config_path], Cluster.config[:global_config_path])
        if @config.verified?
          @config.log_warnings
          @worker_count_manager = initialize_gru
        else
          @config.log_errors
          @pool.premature_quit
        end
      end

      def perform
        check_for_worker_count_adjustment
      end

      def unregister
        remove_counts
        unqueue_all_workers
      end

      def check_for_worker_count_adjustment
        return unless gru_is_inititalized?
        host_count_adjustment = @worker_count_manager.adjust_workers
        adjust_worker_counts(host_count_adjustment) if host_count_adjustment
      end

      private

      def global_prefix
        "cluster:#{Cluster.config[:cluster_name]}:#{Cluster.config[:environment]}"
      end

      def member_prefix
        "#{global_prefix}:#{hostname}"
      end

      def running_workers_key_name
        "#{member_prefix}:running_workers"
      end

      def initialize_gru
        Gru.create(@config.gru_format)
      end

      def hostname
        @hostname ||= Socket.gethostname
      end

      def adjust_worker_counts(count_adjustments)
        count_adjustments.each do |worker, count|
          next if count == 0
          @pool.adjust_worker_counts(worker, count)
          update_counts
        end
      end

      def remove_counts
        Resque.redis.del(running_workers_key_name)
      end

      def unqueue_all_workers
        @worker_count_manager.release_workers if gru_is_inititalized?
      end

      def unqueue_workers(workers)
        workers = Array(workers)
        workers.each do |worker|
          @worker_count_manager.release_workers(worker) if gru_is_inititalized?
        end
      end

      def update_counts
        current_workers = @pool.config
        current_workers.each do |key, value|
          Resque.redis.hset(running_workers_key_name, key, value)
        end
      end

      def gru_is_inititalized?
        ! @worker_count_manager.nil?
      end

    end
  end
end
