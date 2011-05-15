require "#{File.dirname(__FILE__)}/test_helper"
require "#{File.dirname(__FILE__)}/../posterous/client.rb"
require "#{File.dirname(__FILE__)}/../nanoc3/extra/importers/posterous.rb"

FIXTURE_DIR = "#{File.dirname(__FILE__)}/fixtures"

describe "Nanoc3::Extra::Importers::Posterous import posts" do

  def stub_raw(fixture)
    ::Posterous::Resources::Post.new(
      ::JSON.parse( File.read(File.join(FIXTURE_DIR, fixture + ".json")) )
    )
  end
  
  def expected_content(fixture)
    File.read(File.join(FIXTURE_DIR, fixture + "-expected.html")).chomp
  end
  
  def stub_posts_with(*fixtures)
    ::Posterous::Client.any_instance.
      stubs(:posts).
      returns(fixtures.map {|f| stub_raw(f)})
  end
  
  def stub_site
    ds = mock()
    @subject.stubs(:site).returns(stub(:data_sources => [ds]))
  end
  
  def expect_create_item_with(content, attrib, id, params)
    # Nanoc3::Site.stubs(:new).returns(stub(:data_sources => [ds]))
    @subject.site.data_sources[0].expects(:create_item).with(content, attrib, id, params)
  end

  def expect_create_binary_item_with(attrib, id, params)
    @subject.site.data_sources[0].expects(:create_item).with(anything(),attrib, id, {:extension => '.yaml'})
    @subject.site.data_sources[0].expects(:create_item).with(anything(), {}, id, params)
  end
  
  describe "single post, no embedded media" do
  
    before do
      @subject = Nanoc3::Extra::Importers::Posterous.new
      stub_posts_with 'no-image'
      stub_site
      expect_create_item_with expected_content('no-image'),
                              { 'title' => 'Dangerous virus! LOL!',
                                'tags' => ['haha'],
                                'created_at' => '2010/01/25 09:39:00 -0800',
                                'posterous_url' => 'http://ericgj.posterous.com/',
                                'posterous_post_id' => 10553656,
                                'is_private' => false,
                                'posterous_slug' => nil,
                                'audio' => [],
                                'video' => [],
                                'images' => []
                              },
                              '/posts/dangerous-virus-lol-/',
                              :extension => '.html'
    end
    
    it 'should match expected content, attrib, id, and params' do
      @subject.import { images_template = "[[<%= media.identifier %>]]"; posts }
    end
    
  end

#NOTE this test doesn't quite work yet because of subtle differences in HTML output, but it basically works
  describe "single post, single embedded image" do
  
    before do
      @subject = Nanoc3::Extra::Importers::Posterous.new
      stub_posts_with 'one-image'
      stub_site
      expect_create_binary_item_with({'height' => 279,
                                      'width' => 399,
                                      'size' => 34,
                                      'caption' => 'Rare bird\'s breeding ground found in Afghanistan',
                                      'posterous_url' => 'http://posterous.com/getfile/files.posterous.com/ericgj/ZzcQak3Chsq7agpGLFWrDnEOsm2E6bxJtLw4Mg7f9aVbVAkCBq1KlG1sw4t3/afghanistan_bird_of_hope.jpg',
                                      'posterous_user' => 'ericgj',
                                      'posterous_post_id' => 10454692
                                     },
                                     '/images/afghanistan_bird_of_hope-full/',
                                     :extension => '.jpg'
                                    )
      
      expect_create_item_with expected_content('one-image'),
                              { 'title' => 'Rare bird\'s breeding ground found in Afghanistan',
                                'tags' => ['afghanistan','birds'],
                                'created_at' => '2010/01/23 11:45:00 -0800',
                                'posterous_url' => 'http://ericgj.posterous.com/',
                                'posterous_post_id' => 10454692,
                                'is_private' => false,
                                'posterous_slug' => nil,
                                'audio' => [],
                                'video' => [],
                                'images' => ['/images/afghanistan_bird_of_hope-full/']
                              },
                              '/posts/rare-bird-s-breeding-ground-found-in-afghanistan/',
                              :extension => '.html'
    end
    
    it 'should match expected content, attrib, id, and params; and load image' do
      @subject.images_template = "[[<%= media.identifier %>]]"
      @subject.import { posts }
    end
  
  end
  
end
