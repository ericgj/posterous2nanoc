require 'fileutils'
require 'open-uri'
require 'uri'

# usage
#   importer = Nanoc3::Extra::Importers::Posterous.new \
#                :path => '/path/to/target', 
#                :data_source => :filesystem_unified
#   
#   # import whole site including posts, pages, theme
#   importer.import :username => 'user', :password => 'pass', :site => 'mysite'
#   
#   # import selected items (options will be passed as query params)
#   importer.import(:username => 'user', :password => 'pass', :site => 'mysite') do
#     posts :tag => 'starred'
#     pages
#   end
   

module Nanoc3
	module Extra
		module Importers
			class Posterous
        
        attr_reader :client
        attr_reader :identifier_map
        
        def identifier_map
          @identifier_map ||=  \
            { 
              :posts => '/posts/',
              :pages => '/pages/',
              :themes => '/themes/',
              :audio_files => '/audio/',
              :videos => '/video/',
              :images => '/images/'
            }
        end
        
        def initialize(options = {})
          @path, @data_source = options[:path], options[:data_source]
        end
        
        def import(options = {}, &blk)
          if block_given?
            init_client(options)
            create_site_unless_exists
            instance_eval(&blk)
          else
            import(options) { posts; pages; theme }
          end
        end
        
        def posts(options = {})
          client.posts(options).each do |raw| 
            create_post_from raw
          end
        end
        
        def pages(options = {})
          client.pages(options).each do |raw| 
            create_page_from raw
          end
        end
        
        def theme(options = {})
          create_theme_from client.theme(options).parsed_response
        end
        
        private
        
        def init_client(options = {})
          @client = PosterousClient.new(options[:username], options[:password])
          @client.site = options[:site] if options[:site]
          @client.user = options[:user] if options[:user]
          @client
        end
        
        def create_post_from(raw)
          post = Post.new(raw)
          extract_media_from(post)
          create_item_from(post, identifier_map[:posts])
        end
        
        def create_page_from(raw)
          page = Page.new(raw)
          extract_media_from(page)
          create_item_from(page, identifier_map[:pages])
        end
        
        def create_theme_from(raw)
          create_item_from(Theme.new(raw), identifier_map[:themes])
        end
        
        def extract_media_from(item)
          [:audio_files, :images, :video].each do |key|
            item.send(key).each do |it| 
              id = create_binary_item_from(it, identifier_map[key]})
              (item.attributes[identifier_map[key]] ||= []) << id
            end
          end
        end
        
        def create_site_unless_exists
          Nanoc3::CLI::Commands::CreateSite.new.run @path, @data_source
          rescue
        end
        
        #TODO: monkeypatch CreateItem to allow content and attributes
        def create_item_from(item, prefix = nil)
          id = "#{prefix ? prefix.cleaned_identifier : nil}#{item.identifier.cleaned_identifier}"
          FileUtils.cd(@path) do |_|
            Nanoc3::CLI::Commands::CreateItem.new.run \
              id, item.content, item.attributes
          end
          id
        end
        
        #TODO: CreateBinaryItem
        def create_binary_item_from(item, prefix = nil)
          id = "#{prefix ? prefix.cleaned_identifier : nil}#{item.identifier.cleaned_identifier}"
          FileUtils.cd(@path) do |_|
            Nanoc3::CLI::Commands::CreateBinaryItem.new.run \
              id, item.content.path, item.attributes
          end
          id
        end
        
        
        # parser model classes
         
        class Post
          
          attr_reader :raw
          
          def attributes_map
            @attributes_map ||= \
              {
                'title' => 'title',
                'tags' => 'tags',
                'display_date' => 'created_at',
                'full_url' => 'posterous_url',
                'id' => 'posterous_id',
                'is_private' => 'is_private',
                'slug' => 'posterous_slug'
              }
          end
          
          def media_attributes_map
            @media_attributes_map ||= \
              {
                'audio_files' => 'audio',
                'videos' => 'video',
                'images' => 'images',
              }
          end
          
          def initialize(raw)
            @raw = raw
          end
          
          def identifier
            @identifier ||= @raw['title'].downcase.
                              gsub(/[^a-z\-_]/, '-').
                              gsub(/^-+|-+|-+$/, '-').cleaned_identifier
          end
          
          def content
            @content ||= scrubbed_body
          end
          
          # note this does not include media attributes
          # which are added by Posterous.extract_media_from(post)
          # according to identifier mapping
          #
          def attributes
            @attributes ||= \
              Hash[
                nontag_attribute_pairs +
                tag_attribute_pairs
              ]
          end
          
#          def media_attributes
#            media_attributes_map.keys.inject({}) do |memo, key|
#              memo[media_attributes_map[key]] = \
#                media[key].map(&:identifier)
#              memo
#            end
#          end
          
          #TODO note this will have to be done separately for each media type
          #
          def media
            @media ||= \
              @raw['media'].inject({}) do |memo, h|
                memo[h.keys[0]] = h[h.keys[0]].map {|img| Image.new(img['full']) }
                memo
              end
          end
          
          def audio_files
            media['audio_files']
          end
          
          def images
            media['images']
          end
          
          def videos
            media['videos']
          end
          
          private 
          
          def normalized_identifier(name, prefix = nil)
            "#{prefix ? prefix.cleaned_identifier : nil}
             #{name.downcase.\
                  gsub(/[^a-z\-_]/, '-').\
                  gsub(/^-+|-+|-+$/, '-').cleaned_identifier}"
          end
          
          def scrubbed_body
            unescape_html(@raw['body'])
          end
          
          # to deal with escaped unicode code points 
          # because Crack doesn't adequately unescape them due to bug
          def unescape_html(text)
            text.gsub(/\\[u|U]([0-9a-fA-F]{4})/) do |match|
              [$1.to_i(16)].pack('U')
            end
          end
                              
          def nontag_attribute_pairs
            (attributes_map.keys - ['tags']).map do |key|
              [ attributes_map[key], @raw[key.to_s] ]
            end
          end
          
          def tag_attribute_pairs
            [ attributes_map['tags'], @raw['tags'].map {|t| t['name']} ]
          end
                    
        end
        
        
        class Image
        
          attr_reader :raw
                  
          def initialize(raw)
            @raw = raw
          end
          
          # Note this is the basic item identifier, without prefix
          def identifier
            @identifier ||= \
              normalized_identifier(basename)
          end
          
          def basename
            File.basename(URI.parse(@raw['url']).path.split("/").last, '.*')
          end
          
          def extension
            File.extension(URI.parse(@raw['url']).path.split("/").last)
          end
          
          # as tempfile
          def content
            f = Tempfile.new(basename)
            f.unlink
            open(@raw['url']) do |data|
              f.write data.read
            end
            f.rewind
            f
          end

          def attributes
            #TODO
          end
                    
          private
          
          def normalized_identifier(name, prefix = nil)
            "#{prefix ? prefix.cleaned_identifier : nil}
             #{name.downcase.\
                  gsub(/[^a-z\-_]/, '-').\
                  gsub(/^-+|-+|-+$/, '-').cleaned_identifier}"
          end
          
        end
        
			end
    end
  end
end