class TestMemberManager

  def initialize(local_config_path, global_config_path, cluster_name = "test-cluster", environment = "test")
    @local_config_path = local_config_path
    @global_config_path = global_config_path
    @cluster_name = cluster_name
    @environment = environment
    @pid = nil
    @pool_master_pid = nil
  end

  def start
    ENV['GRU_HOSTNAME'] = hostname
    @pid = spawn("bundle exec spec/integration/bin/resque-cluster_member_test -c #{@local_config_path} -E #{@environment}#{@cluster_name.nil? ? "" : " -C "+@cluster_name} -G #{@global_config_path}")

    while ( @pool_master_pid.nil? ) do
      sleep(0.1)
      child_process = @pid #`pgrep -P #{@pid}`.strip
      pool = `ps -p #{child_process} -hf | grep 'resque-pool-master\\[resque-cluster\\]: managing \\[' | awk '{print $1}'`.strip.to_i
      @pool_master_pid = pool > 0 ? pool : nil
    end
    puts "Pool Master pid is ---------- #{@pool_master_pid}"
  end

  def stop
    puts "************************************************ About to kill : Pool Master pid ---------- #{@pool_master_pid}"
    Process.kill(:TERM, @pool_master_pid)
    while ( @pool_master_pid ) do
      pool = `ps -p #{@pool_master_pid} -hf | grep 'resque-pool-master\\[resque-cluster\\]: managing \\[' | awk '{print $1}'`.strip.to_i
      @pool_master_pid = pool > 0 ? pool : nil
    end
    @pid = nil
    sleep(5)
  end

  def counts
    return {} unless @pool_master_pid
    local_workers = `ps --ppid #{@pool_master_pid} -fh | awk '{print $8}'`.split
    TestMemberManager.worker_counts(local_workers)
  end

  def self.counts
    all_workers = `ps -ef | grep "resque-" | grep "Waiting for" | grep -v ps| awk '{print $11}'`.split
    worker_counts(all_workers)
  end

  def self.worker_counts(worker_array)
    final_counts = Hash.new(0)

    worker_array.each do |worker|
      final_counts[worker] += 1
    end

    final_counts
  end

  def hostname
    @hostname ||= "#{Socket.gethostname}-#{member_count+1}"
  end

  def self.stop_all
    pools = `ps -ef | grep 'resque-pool-master\\[resque-cluster\\]: managing \\[' | awk '{print $2}'`.split
    `kill #{pools.join(' ')}` unless pools.empty?
    sleep(3)
  end

  def member_count
    `ps -ef | grep resque-pool-master | grep -v grep|wc -l`.strip.to_i
  end
end
