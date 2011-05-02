require "#{File.dirname(__FILE__)}/test_helper"
require "#{File.dirname(__FILE__)}/../posterous/client.rb"

FIXTURE_DIR = "#{File.dirname(__FILE__)}/fixtures"

describe "Posterous::Resources::Post images" do

  def stub_raw(fixture)
    ::JSON.parse( File.read(File.join(FIXTURE_DIR, fixture + ".json")) )
  end
  
  def assert_found_matching_image(input, scale)
    img = @subject.images.find {|i| i.scale == scale && i.attributes[i.attributes_map['url']] == input[scale]['url']}
    refute_nil img
    img.attributes_map.each do |source, dest|
      assert_equal input[scale][source], img.attributes[dest]
    end
  end
  
  describe "no images in post" do
  
    before do
      @subject = Posterous::Resources::Post.new(@input = stub_raw('no-image'))
    end
    
    it "returns an empty array" do
      @subject.images.must_be_kind_of Array
      @subject.images.must_be_empty
    end
    
  end

  describe "one image in post (scale 'full')" do
  
    before do
      @subject = Posterous::Resources::Post.new(@input = stub_raw('one-image'))
    end
    
    it "returns a one-element array" do
      @subject.images.must_be_kind_of Array
      @subject.images.size.must_equal 1
    end
       
       
    it "contains an Image scaled 'full' matching input image" do
      imgs = @input['media'].find {|h| h['images']}
      assert_found_matching_image imgs['images'][0], 'full'
    end
    
  end
  
  describe "multiple images in post" do
  
    before do
      @subject = Posterous::Resources::Post.new(@input = stub_raw('multi-image'))
    end
    
    it "contains an Image scale 'full' matching each input image" do
      imgs = @input['media'].find {|h| h['images']}
      i=0
      imgs['images'].each do |h|
        i+=1
        assert_found_matching_image h, 'full'
      end
      assert i>1, "expected >1 image in input, found #{i}"
    end
    
    it "contains an Image matching input image scale 'scaled500'" do
      imgs = @input['media'].find {|h| h['images']}
      i=0
      imgs['images'].each do |h|
        i+=1
        assert_found_matching_image h, 'scaled500'
      end
      assert i>1, "expected >1 image in input, found #{i}"
    end
    
  end
  
  
end

