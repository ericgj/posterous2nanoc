require "#{File.dirname(__FILE__)}/test_helper"
require "#{File.dirname(__FILE__)}/../posterous/client.rb"

FIXTURE_DIR = "#{File.dirname(__FILE__)}/fixtures"

describe "Posterous::Resources::Post update_images" do

  def stub_raw(fixture)
    ::JSON.parse( File.read(File.join(FIXTURE_DIR, fixture + ".json")) )
  end
  
  describe "one image in post, embedded once" do
  
    before do
      @subject = Posterous::Resources::Post.new(@input = stub_raw('one-image-one-embed'))
    end
    
    it 'should find one tag' do
      i=0
      @subject.update_images {|tag| i+=1}
      assert_equal 1, i
    end
    
  end
end
