require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

LOCAL_CONFIG = "spec/integration/config/local_config.yml"
GLOBAL_CONFIG = "spec/integration/config/global_config.yml"
BAD_GLOBAL_CONFIG = "spec/integration/config/bad_global_config.yml"
BAD_LOCAL_CONFIG = "spec/integration/config/bad_local_config.yml"
LOCAL_CONFIG2 = "spec/integration/config/local_config2.yml"
GLOBAL_CONFIG2 = "spec/integration/config/global_config2.yml"
GLOBAL_REBALANCE_CONFIG2 = "spec/integration/config/global_rebalance_config2.yml"
GLOBAL_REBALANCE_CONFIG3 = "spec/integration/config/global_rebalance_config3.yml"
REBALANCE_CONFIG = "spec/integration/config/rebalance_config.yml"
GLOBAL_CONFIG3 = "spec/integration/config/global_config3.yml"
GLOBAL_CONFIG4 = "spec/integration/config/global_config4.yml"

RSpec.describe "Resque test-cluster" do
  context "Spin Up and Down" do
    before :all do
      @a = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_CONFIG)
      @b = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_CONFIG)
      @c = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_CONFIG)
    end

    it 'expects no workers to be running' do
      expect(TestMemberManager.counts).to be_empty
      expect(@a.counts).to be_empty
      expect(@b.counts).to be_empty
      expect(@c.counts).to be_empty
    end

    it 'expects counts to be correct after workers get spun up' do
      @a.start
      @b.start
      @c.start
      expect(TestMemberManager.counts).to eq({"par"=>2, "tar"=>8, "par,tar,var"=>1})
    end

    it 'cluster adjusts correctly when a member stops and doesn\'t let global counts become negative' do
      @a.stop
      expect(TestMemberManager.counts).to eq({"tar"=>6, "par"=>2, "par,tar,var"=>1})
      expect(@a.counts).to be_empty
      @b.stop
      expect(TestMemberManager.counts).to eq({"tar"=>3, "par"=>1, "par,tar,var"=>1})
      expect(@b.counts).to be_empty
      Resque.redis.redis.hset("GRU:test:test-cluster:global:workers_running", "par", "-1")
      sleep(1)
      expect(Resque.redis.redis.hget("GRU:test:test-cluster:global:workers_running", "par")).to eq("0")
      @c.stop
    end

    after :all do
      TestMemberManager.stop_all
    end

  end

  context "Cluster with bad configs" do
    before :all do
      @d = TestMemberManager.new(LOCAL_CONFIG2, BAD_GLOBAL_CONFIG)
      @e = TestMemberManager.new(BAD_LOCAL_CONFIG, GLOBAL_REBALANCE_CONFIG2)
      @f = TestMemberManager.new("", "")
      @d.start
      @e.start
      @f.start
      sleep(5) # rebalance time
    end

    it 'expects counts to be correct after workers get spun up' do
      expect(TestMemberManager.counts).to eq({})
      expect(@d.is_running?).to eq(false)
      expect(@e.is_running?).to eq(false)
      expect(@f.is_running?).to eq(false)
      expect(TestMemberManager.resque_cluster_members.count).to eq(0)
    end

    after :all do
      TestMemberManager.stop_all
    end

  end


  context "Cluster with Rebalancing" do
    before :all do
      @d = TestMemberManager.new(LOCAL_CONFIG2, GLOBAL_REBALANCE_CONFIG2)
      @e = TestMemberManager.new(LOCAL_CONFIG2, GLOBAL_REBALANCE_CONFIG2)
      @f = TestMemberManager.new(LOCAL_CONFIG2, GLOBAL_REBALANCE_CONFIG2)
      @d.start
      @e.start
      @f.start
      sleep(5) # rebalance time
    end

    it 'expects counts to be correct after workers get spun up' do
      expect(TestMemberManager.counts).to eq({"star"=>12})
      expect(@d.counts).to eq({"star"=>4})
      expect(@e.counts).to eq({"star"=>4})
      expect(@f.counts).to eq({"star"=>4})
    end

    it 'adjusts correctly when a member stops' do
      @d.stop
      expect(TestMemberManager.counts).to eq({"star"=>12})
      expect(@d.counts).to be_empty
      expect(@e.counts).to eq({"star"=>6})
      expect(@f.counts).to eq({"star"=>6})
      @e.stop
      @f.stop
    end

    after :all do
      TestMemberManager.stop_all
    end

  end

  context "Multiple Clusters and Environments" do
    before :all do
      @a = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_CONFIG3)
      @b = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_CONFIG3, "test1-cluster")
      @c = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_CONFIG3, "test-cluster", "test1")
      @a.start
      @b.start
      @c.start
      sleep(5) # rebalance time
    end

    it 'expects counts to be independent of each other' do
      expect(TestMemberManager.counts).to eq({"tar"=>9, "par"=>3, "par,tar,var"=>3})
      expect(@a.counts).to eq({"tar"=>3, "par"=>1, "par,tar,var"=>1})
      expect(@b.counts).to eq({"tar"=>3, "par"=>1, "par,tar,var"=>1})
      expect(@c.counts).to eq({"tar"=>3, "par"=>1, "par,tar,var"=>1})
    end

    after :all do
      TestMemberManager.stop_all
    end
  end

  context "Rebalance after global maximums change" do
    before :all do
      @a = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_CONFIG3)
      @b = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_CONFIG3)
      @c = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_REBALANCE_CONFIG3)
      @a.start
      @b.start
      sleep(3) # rebalance time
    end

    it 'expects to have each cluster member only running workers in its config' do
      expect(TestMemberManager.counts).to eq('par' => 2, 'tar' => 6, 'par,tar,var' => 1)
      expect(@a.counts).to eq('par' => 1, 'tar' => 3, 'par,tar,var' => 1)
      expect(@b.counts).to eq('par' => 1, 'tar' => 3)
    end

    it 'expects the cluster to redistribute correctly after global config change' do
      @c.start
      sleep(8) # rebalance time
      expect(TestMemberManager.counts).to eq('par' => 3, 'tar' => 6, 'par,tar,var' => 2)
      expect(@a.counts).to eq('par' => 1, 'tar' => 2, 'par,tar,var' => 1)
      expect(@b.counts).to eq('par' => 1, 'tar' => 2, 'par,tar,var' => 1)
      expect(@c.counts).to eq('par' => 1, 'tar' => 2)
    end

    after :all do
      TestMemberManager.stop_all
    end
  end

  context "Rebalance and non rebalance global configs switching in a cluster" do
    before :all do
      @a = TestMemberManager.new(LOCAL_CONFIG2, GLOBAL_REBALANCE_CONFIG2)
      @b = TestMemberManager.new(LOCAL_CONFIG2, GLOBAL_CONFIG2)
      @c = TestMemberManager.new(LOCAL_CONFIG2, GLOBAL_REBALANCE_CONFIG2)
      @a.start
      @b.start
      @c.start
      sleep(5) # rebalance time
    end

    it 'expects to have a correct number of workers in the cluster after multiple restarts' do
      expect(TestMemberManager.counts).to eq({"star"=>12})
      2.times do
        sleep(5)
        @a.stop
        @a.start
        sleep(5)
        @b.stop
        @b.start
        sleep(5)
        @c.stop
        @c.start
      end
      sleep(8) # rebalance time
      expect(TestMemberManager.counts).to eq({"star"=>12})
      expect(@a.counts).to eq({"star"=>4})
      expect(@b.counts).to eq({"star"=>4})
      expect(@c.counts).to eq({"star"=>4})
    end

    it 'will not rebalance after the cluster is switched to rebalance-cluster false' do
      @b.stop
      sleep(2)
      @b.start
      sleep(8)
      expect(TestMemberManager.counts).to eq({"star"=>12})
      expect(@a.counts).to eq({"star"=>6})
      expect(@b.counts).to eq({})
      expect(@c.counts).to eq({"star"=>6})
    end

    after :all do
      TestMemberManager.stop_all
    end
  end

  context "In case one member gets reaped, the cluster rebalances after assuming a member dead" do
    before :all do
      sleep 5
      @a = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_CONFIG3)
      @b = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_CONFIG3)
      @c = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_CONFIG3)
    end

    it 'expects no workers to be running' do
      expect(TestMemberManager.counts).to be_empty
      expect(@a.counts).to be_empty
      expect(@b.counts).to be_empty
      expect(@c.counts).to be_empty
    end

    it 'expects counts to be correct after workers get spun up' do
      @a.start
      @b.start
      @c.start
      expect(TestMemberManager.counts).to eq({"par"=>2, "tar"=>8, "par,tar,var"=>1})
    end

    it 'cluster adjusts correctly when a member gets reaped' do
      @a.kill
      sleep(10)
      expect(TestMemberManager.counts).to eq({"tar"=>6, "par"=>2, "par,tar,var"=>1})
      expect(@a.counts).to be_empty
    end

    it 'cluster rebalances correctly when the member gets brought back up' do
      @a.start
      expect(TestMemberManager.counts).to eq({"par"=>2, "tar"=>8, "par,tar,var"=>1})
    end

    after :all do
      TestMemberManager.stop_all
    end

  end

  context "Cluster with Rebalancing And max_workers_per_host set" do
    before :all do
      @g = TestMemberManager.new(LOCAL_CONFIG2, GLOBAL_CONFIG4)
      @h = TestMemberManager.new(LOCAL_CONFIG2, GLOBAL_CONFIG4)
      @i = TestMemberManager.new(LOCAL_CONFIG2, GLOBAL_CONFIG4)
      @g.start
      @h.start
      @i.start
      sleep(5) # rebalance time
    end

    it 'expects counts to be correct after workers get spun up' do
      expect(TestMemberManager.counts).to eq({"star"=>12})
      expect(@g.counts).to eq({"star"=>4})
      expect(@h.counts).to eq({"star"=>4})
      expect(@g.counts).to eq({"star"=>4})
    end

    it 'adjusts correctly when a member stops' do
      @g.stop
      expect(TestMemberManager.counts).to eq({"star"=>10})
      expect(@g.counts).to be_empty
      expect(@h.counts).to eq({"star"=>5})
      expect(@i.counts).to eq({"star"=>5})
      @h.stop
      @i.stop
    end

    after :all do
      TestMemberManager.stop_all
    end

  end


end
