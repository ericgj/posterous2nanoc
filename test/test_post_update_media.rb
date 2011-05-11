require "#{File.dirname(__FILE__)}/test_helper"
require "#{File.dirname(__FILE__)}/../posterous/client.rb"

FIXTURE_DIR = "#{File.dirname(__FILE__)}/fixtures"

describe "Posterous::Resources::Post update_images" do

  def stub_raw(fixture)
    ::JSON.parse( File.read(File.join(FIXTURE_DIR, fixture + ".json")) )
  end
  
  def image_tags
    dom = Nokogiri::HTML.fragment(@subject.updated_content)
    dom.xpath *(@subject.images.map(&:xpath))
  end

  def image_tags_for(img)
    dom = Nokogiri::HTML.fragment(@subject.updated_content)
    dom.xpath img.xpath
  end
  
  describe "no image in post" do
    before do
      @subject = Posterous::Resources::Post.new(@input = stub_raw('no-image'))
    end
  
    it 'should not find any tag' do
      i=0
      @subject.update_images {|tag, _| i+=1}
      assert_equal 0, i
    end
    
    it 'should not update post content' do
      @subject.update_images {|tag, _| tag['foo'] = "Hi"}
      assert_equal @subject.content, @subject.updated_content
    end
    
  end
  
  describe "one image in post, embedded once" do
  
    before do
      @subject = Posterous::Resources::Post.new(@input = stub_raw('one-image-one-embed'))
    end
    
    it 'should find one tag' do
      i=0
      @subject.update_images {|tag, _| i+=1}
      assert_equal 1, i
    end
    
    it 'should yield matching tag and image objects' do
      @subject.update_images do |tag, img|
        assert_equal tag['src'], img['posterous_url']
      end
    end
    
    it 'should be able to update tag content' do
      @subject.update_images {|tag, _| tag['foo'] = "Hi"}
      #puts @subject.updated_content
      assert_equal 1, image_tags.length
      image_tags.each {|tag| assert_equal "Hi", tag['foo']}
    end
    
    it 'should be able to replace tag' do
      @subject.update_images do |tag, img|
        div = tag.parent
        div.add_child "<foo>#{img.identifier}</foo>"
        tag.remove
      end
      #puts @subject.updated_content
      dom = Nokogiri::HTML.fragment(@subject.updated_content)
      assert_equal 1, dom.xpath('.//foo').length
    end
    
  end

  describe "multiple images in post, each embedded once" do
  
    before do
      @subject = Posterous::Resources::Post.new(@input = stub_raw('multi-image'))
    end
    
    it 'should find two tags' do
      i=0
      @subject.update_images {|tag, _| i+=1}
      assert_equal 2, i
    end
    
    it 'should be able to update tag content' do
      embeds = []
      @subject.update_images do |tag, img| 
        tag['foo'] = "Hi"
        embeds << img
      end
      #puts @subject.updated_content
      refute_equal 0, embeds
      embeds.each do |img| 
        assert_equal 1, image_tags_for(img).length
        assert_equal "Hi", image_tags_for(img).first['foo']
      end
    end
    
    it 'should be able to replace tag' do
      embeds = []
      @subject.update_images do |tag, img|
        div = tag.parent
        div.add_child "<foo id='#{img.identifier}'></foo>"
        tag.remove
        embeds << img
      end
      
      dom = Nokogiri::HTML.fragment(@subject.updated_content)
      
      refute_equal 0, embeds
      embeds.each do |img|
        assert_equal 1, dom.xpath(".//foo[@id='#{img.identifier}']").length
      end
    end
    
  end
  
end
