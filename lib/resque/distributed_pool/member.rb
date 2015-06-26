require 'socket'
require 'gru'

module Resque
  class DistributedPool
    # Member is a single member of a resque pool cluster
    class Member
      attr_reader :hostname, :pool, :local_config, :global_config

      def initialize(started_pool)
        @hostname = Socket.gethostname
        @pool = started_pool
        @local_config = parse_config(DistributedPool.config[:local_config_path])
        @global_config = parse_config(DistributedPool.config[:global_config_path])
        @global_config = @local_config if global_config.empty?
        @worker_count_manager = setup_gru

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
        "cluster:#{DistributedPool.config[:cluster_name]}:#{DistributedPool.config[:environment]}"
      end

      def member_prefix
        "#{global_prefix}:#{@hostname}"
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

      def setup_gru
        client = Redis.new(Resque.redis.client.options)
        Gru.with_redis_connection(client, @local_config, @global_config)
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
    end
  end
end
