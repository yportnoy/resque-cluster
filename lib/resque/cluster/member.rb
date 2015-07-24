require 'socket'
require 'gru'

module Resque
  class Cluster
    # Member is a single member of a resque pool cluster
    class Member
      attr_reader :hostname, :pool, :local_config, :global_config

      def initialize(started_pool)
        @pool = started_pool
        @local_config = parse_config(Cluster.config[:local_config_path])
        @global_config = parse_config(Cluster.config[:global_config_path])
        @global_config = @local_config if global_config.empty?
        @worker_count_manager = initialize_gru

        register
      end

      def perform
        check_for_worker_count_adjustment
        ping
      end

      def register
        ping
      end

      def unregister
        unping
        remove_counts
        unqueue_all_workers
      end

      def check_for_worker_count_adjustment
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

      def ping
        Resque.redis.hset(global_prefix, hostname, Time.now.utc)
      end

      def unping
        Resque.redis.hdel(global_prefix, hostname)
      end

      def initialize_gru
        Gru.create(cluster_member_settings)
      end

      def hostname
        @hostname ||= Socket.gethostname
      end

      def adjust_worker_counts(count_adjustments)
        count_adjustments.each do |worker, count|
          @pool.adjust_worker_counts(worker, count)
          update_counts
        end
      end

      def parse_config(config_path)
        return {} unless config_path && File.exist?(config_path)
        YAML.load(ERB.new(IO.read(config_path)).result)
      end

      def remove_counts
        Resque.redis.del(running_workers_key_name)
      end

      def unqueue_all_workers
        @worker_count_manager.release_workers
      end

      def unqueue_workers(workers)
        workers = Array(workers)
        workers.each do |worker|
          @worker_count_manager.release_workers(worker)
        end
      end

      def update_counts
        current_workers = @pool.config
        current_workers.each do |key, value|
          Resque.redis.hset(running_workers_key_name, key, value)
        end
      end

      def cluster_member_settings
        {
          cluster_maximums: @global_config["global_maximums"] || @global_config,
          host_maximums:    @local_config,
          client_settings:  Resque.redis.client.options,
          rebalance_flag:   @global_config["rebalance_cluster"] || false,
          cluster_name:     Cluster.config[:cluster_name],
          environment_name: Cluster.config[:environment]
        }
      end
    end
  end
end
