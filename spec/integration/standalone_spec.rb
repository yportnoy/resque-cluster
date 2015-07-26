require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

LOCAL_CONFIG = "spec/integration/config/local_config.yml"
GLOBAL_CONFIG = "spec/integration/config/global_config.yml"

RSpec.describe "resque-cluster" do
  context "running 3 resque-cluster members in a standalone mode" do
    before :all do
      @a = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_CONFIG, nil)
      @b = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_CONFIG, nil)
      @c = TestMemberManager.new(LOCAL_CONFIG, GLOBAL_CONFIG, nil)
    end

    it 'expects no workers to be running' do
      expect(@a.counts).to be_empty
      expect(@b.counts).to be_empty
      expect(@c.counts).to be_empty
    end

    it 'expects total counts to be correct after workers get spun up' do
      @a.start
      @b.start
      @c.start
      sleep(5)
      expect(TestMemberManager.counts).to eq({"par"=>3, "tar"=>9, "par,tar,var"=>3})
    end

    it 'expects each resque-pool to have the same counts' do
      expect(@a.counts).to eq({"par"=>1, "tar"=>3, "par,tar,var"=>1})
      expect(@b.counts).to eq({"par"=>1, "tar"=>3, "par,tar,var"=>1})
      expect(@c.counts).to eq({"par"=>1, "tar"=>3, "par,tar,var"=>1})
    end

    after :all do
      TestMemberManager.stop_all
    end
  end
end
