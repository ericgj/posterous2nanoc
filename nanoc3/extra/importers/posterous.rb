require 'nanoc3'
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
      class Base
      
        attr_accessor :path
        def path; @path ||= '.'; end
        
        # NOTE: lifted from CLI::Base
        # Gets the site ({Nanoc3::Site} instance) in the specified or current directory and
        # loads its data.
        #
        # @return [Nanoc3::Site] The site in the specified or current directory
        def site
          # Load site if possible
          FileUtils.cd(self.path) do |dir|
            if File.file?('config.yaml') && (!self.instance_variable_defined?(:@site) || @site.nil?)
              @site = Nanoc3::Site.new('.')
            end
          end
          @site
        end
        
        def create_item(content, attrib, id, params = {})
         
          self.site.data_sources[0].create_item(
            content,
            attrib,
            id,
            params
          )
        end
        
      end
    end
  end
end

module Nanoc3
	module Extra
		module Importers
			class Posterous < Base
        
        attr_reader :client
        attr_reader :identifier_map
        
        attr_accessor :image_template,
                      :video_template,
                      :audio_file_template
        
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
        
        def image_template
          @image_template ||= \
            "[[<%= object.identifier %>]]"
        end
        
        def initialize(options = {})
          @path = options[:path] || '.'
          @data_source = options[:data_source]
        end
        
        def import(options = {}, &blk)
          if block_given?
            init_client(options)
            #create_site_unless_exists
            instance_eval(&blk)
          else
            import(options) { posts; pages; theme }
          end
        end
        
        def posts(options = {})
          client.posts(options).each do |post| 
            create_post_from post
          end
        end
        
        def pages(options = {})
          client.pages(options).each do |page| 
            create_page_from page
          end
        end
        
        def theme(options = {})
          create_theme_from client.theme(options)
        end
        
        private
        
        def init_client(options = {})
          ::Posterous::Client.resources :post => Post
                                              
          @client = ::Posterous::Client.new(options[:username], options[:password])
          @client.site = options[:site] if options[:site]
          @client.user = options[:user] if options[:user]
          @client
        end
        
        def create_post_from(post)
          extract_media_from(post)
          update_media_tags_in(post)
          create_item_from(post, identifier_map[:posts])
        end
        
        def create_page_from(page)
          extract_media_from(page)
          update_media_tags_in(page)
          create_item_from(page, identifier_map[:pages])
        end
        
        #TODO extract top image from this?
        def create_theme_from(theme)
          create_item_from(theme, identifier_map[:themes])
        end
        
        def extract_media_from(item)
          [:audio_files, :images, :videos].each do |key|
            item.send(key).each do |raw| 
              id = create_binary_item_from(raw, identifier_map[key], raw.content)
              raw.identifier = id
            end
          end
        end
        
        def update_media_tags_in(item)
        
          klass = Class.new {
            def initialize(obj); @object = obj; end
            def get_binding; binding(); end
          }

          item.update_images do |tag|
            div = tag.parent
            tag.remove
            div.add ERB.new(image_template).result(klass.new(tag).get_binding)
          end
          
          # TODO for audio_files, videos
        end
        
        # NOTE this is not done now, it assumes site exists
        def create_site_unless_exists
          ::Nanoc3::CLI::Commands::CreateSite.new.run @path, @data_source
          rescue
        end
        
        # NOTE both of these assume a filesystem_unified data source
        
        def create_item_from(item, prefix = nil)
          id = "#{prefix ? prefix.cleaned_identifier : nil}#{item.identifier.cleaned_identifier}"
          create_item item.content, item.attributes, id, :extension => 'html'
          id
        end
        
        def create_binary_item_from(item, prefix = nil, filename_or_io = nil)          
          id = "#{prefix ? prefix.cleaned_identifier : nil}#{item.identifier.cleaned_identifier}"
          create_item '', item.attributes, id, :extension => 'yaml'
          
          if filename_or_io.respond_to?(:read)
            create_item filename_or_io.read, {}, id, :extension => item.extension
          else
            if String === filename_or_io
              File.open(filename_or_io) do |f|
                create_item f.read, {}, id, :extension => item.extension
              end
            end
          end
          
          id
        end

        # parser model classes -- moved to Posterous namespace
        
      end
    end
  end
end

