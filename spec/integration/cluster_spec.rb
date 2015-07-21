require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

RSpec.describe "Resque test-cluster" do
  context "Spin Up and Down" do
    before :all do
      @a = TestMemberManager.new("spec/integration/local_config.yml", "spec/integration/global_config.yml", false)
      @b = TestMemberManager.new("spec/integration/local_config.yml", "spec/integration/global_config.yml", false)
      @c = TestMemberManager.new("spec/integration/local_config.yml", "spec/integration/global_config.yml", false)
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
  end

  context "Cluster with Rebalancing" do
    before :all do
      @d = TestMemberManager.new("spec/integration/local_rebalance_config.yml", "spec/integration/global_rebalance_config.yml", true)
      @e = TestMemberManager.new("spec/integration/local_rebalance_config.yml", "spec/integration/global_rebalance_config.yml", true)
      @f = TestMemberManager.new("spec/integration/local_rebalance_config.yml", "spec/integration/global_rebalance_config.yml", true)
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

    it 'cluster adjusts correctly when a member stops' do
      @d.stop
      expect(TestMemberManager.counts).to eq({"star"=>12})
      expect(@d.counts).to be_empty
      expect(@e.counts).to eq({"star"=>6})
      expect(@f.counts).to eq({"star"=>6})
      @e.stop
      @f.stop
    end
  end

end
