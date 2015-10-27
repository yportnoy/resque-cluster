require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

LOCAL_CONFIG = "spec/integration/config/local_config.yml"
GLOBAL_CONFIG = "spec/integration/config/global_config.yml"
LOCAL_CONFIG2 = "spec/integration/config/local_config2.yml"
GLOBAL_CONFIG2 = "spec/integration/config/global_config2.yml"
GLOBAL_REBALANCE_CONFIG2 = "spec/integration/config/global_rebalance_config2.yml"
GLOBAL_CONFIG3 = "spec/integration/config/global_config3.yml"

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

    it 'cluster adjusts correctly when a member stops' do
      @a.stop
      expect(TestMemberManager.counts).to eq({"tar"=>6, "par"=>2, "par,tar,var"=>1})
      expect(@a.counts).to be_empty
      @b.stop
      expect(TestMemberManager.counts).to eq({"tar"=>3, "par"=>1, "par,tar,var"=>1})
      expect(@b.counts).to be_empty
      @c.stop
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
      @a = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_CONFIG)
      @b = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_CONFIG, "test1-cluster")
      @c = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_CONFIG, "test-cluster", "test1")
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

  context "Multiple Configs in the same cluster" do
    before :all do
      @a = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_CONFIG)
      @b = TestMemberManager.new(LOCAL_CONFIG2, GLOBAL_CONFIG)
      @c = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_REBALANCE_CONFIG2)
      @a.start
      @b.start
      sleep(3) # rebalance time
    end

    it 'expects to have each cluster member only running workers in it\'s config' do
      expect(TestMemberManager.counts).to eq({"tar"=>3, "par"=>1, "par,tar,var"=>1})
      expect(@a.counts).to eq({"tar"=>3, "par"=>1, "par,tar,var"=>1})
      expect(@b.counts).to be_empty
    end

    it 'expects the cluster to redistribute correctly after global config change' do
      @c.start
      sleep(8) # rebalance time
      expect(TestMemberManager.counts).to eq({"star"=>4})
      expect(@a.counts).to be_empty
      expect(@b.counts).to eq({"star"=>4})
      expect(@c.counts).to be_empty
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

end
