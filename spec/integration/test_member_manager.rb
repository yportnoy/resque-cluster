class TestMemberManager
  include Sys
  require 'resque/cluster/config'

  attr_accessor :pid

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
    count = 0

    while ( @pool_master_pid.nil? && count <= 100 ) do
      sleep(0.1)

      if (ProcTable.ps(@pid) &&
          ProcTable.ps(@pid).cmdline =~ /resque-pool-master\[resque-cluster\]:\smanaging\s\[/)
        pool_pid = ProcTable.ps(@pid).pid
      end

      @pool_master_pid = pool_pid ? pool_pid : nil
      count += 1
    end

    puts "Pool Master pid is ---------- #{@pool_master_pid}" if @pool_master_pid
  end

  def stop
    puts "************************************************ About to kill : Pool Master pid ---------- #{@pool_master_pid}"
    Process.kill(:QUIT, @pool_master_pid)
    while ( @pool_master_pid ) do
      if (ProcTable.ps(@pool_master_pid) &&
          ! (ProcTable.ps(@pool_master_pid).cmdline =~ /resque-pool-master\[resque-cluster\]:\smanaging\s\[/))
        @pool_master_pid = nil
      end
    end
    @pid = nil
    sleep(3)
  end

  def is_running?
    (ProcTable.ps(@pid).instance_of? (Struct::ProcTableStruct)) &&
      ! (ProcTable.ps(@pid).cmdline =~ /resque-pool-master\[resque-cluster\]:\smanaging\s\[/).nil?
  end

  def kill
    puts "************************************************ About to kill -9 : Pool Master pid ---------- #{@pool_master_pid}"
    Process.kill(:TERM, @pool_master_pid)
    while ( @pool_master_pid ) do
      if (ProcTable.ps(@pool_master_pid) &&
          ! (ProcTable.ps(@pool_master_pid).cmdline =~ /resque-pool-master\[resque-cluster\]:\smanaging\s\[/))
        @pool_master_pid = nil
      end
    end
    @pid = nil
    sleep(3)
  end

  def counts
    return {} unless @pool_master_pid
    local_workers = ProcTable.ps.select{|p| p.ppid == @pool_master_pid}.map(&:cmdline)
    TestMemberManager.worker_counts(local_workers)
  end

  def self.counts
    pool_pids = resque_cluster_members.map(&:pid)
    all_workers = ProcTable.ps.select{|p| pool_pids.include? p.ppid}.map(&:cmdline)
    worker_counts(all_workers)
  end

  def self.worker_counts(worker_array)
    final_counts = Hash.new(0)

    worker_array.each do |worker_cmdline|
      worker = parse_worker_name(worker_cmdline)
      final_counts[worker] += 1
    end

    final_counts
  end

  def hostname
    @hostname ||= "#{Socket.gethostname}-#{member_count+1}"
  end

  def last_gru_ping
    redis_connection.hget("GRU:#{@environment}:#{@cluster_name}:heartbeats", hostname).to_i
  end

  def redis_connection
    @redis_connection ||= Redis.new
  end

  def self.parse_worker_name(worker_cmdline)
    worker_cmdline.gsub(/resque(\d|\.|-)*:\sWaiting\sfor\s/, '')
  end

  def self.stop_all
    TestMemberManager.resque_cluster_members.each do |member|
      Process.kill(:TERM, member.pid)
    end
    sleep(3)
  end

  def member_count
    TestMemberManager.resque_cluster_members.count
  end

  def self.resque_cluster_members
    ProcTable.ps.select{|p| p.cmdline =~ /resque-pool-master/}
  end

end
