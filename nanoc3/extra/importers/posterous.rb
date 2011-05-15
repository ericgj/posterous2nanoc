require 'nanoc3'
require 'fileutils'
require 'erb'

# Usage
#
#   # initialize importer with Nanoc filesystem info
#
#      importer = Nanoc3::Extra::Importers::Posterous.new \
#                   :path => '/path/to/target/site', 
#                   :data_source => :filesystem_unified
#   
#   # import whole site including posts, pages, theme
#
#     importer.import :username => 'user', :password => 'pass', :site => 'mysite'
#   
#   # import selected items (options will be passed as query params)
#
#     importer.import(:username => 'user', :password => 'pass', :site => 'mysite') do
#       posts :tag => 'starred'
#       pages
#     end
#
#   # set mapping for Posterous item types => Nanoc identifier prefixes
#
#     importer.identifier_map[:posts] => '/blog/'
#
#   # set template for converting posterous image tags
#   # NOTE this is a work in progress, may be a simpler way

#     importer.images_template = "<img src='<%%= items.find {|it| it.identifier == '<%= media.identifier %>'}.path %%>' />"
#
#   # or this is a way I simplify image embedding in nanoc -- 
#     importer.images_template = "[[<%= media.identifier %>]]"   
#  
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
          FileUtils.cd(self.path) do |dir|
            if File.file?('config.yaml') && (!self.instance_variable_defined?(:@site) || @site.nil?)
              @site = Nanoc3::Site.new('.')
            end
          end
          @site
        end
        
        # TODO raise error (or output to stderr ?) unless self.site
        def create_item(content, attrib, id, params = {})
          # unless self.site raise 
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
        
        attr_accessor :images_template,
                      :video_template,
                      :audio_file_template
        
        attr_accessor :output
        
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
        
        
        def output; @output ||= $stderr; end
        
        def initialize(options = {})
          @path = options[:path] || '.'
          @data_source = options[:data_source]
          @counter = Hash.new(0)
       end
        
        #TODO check arity and `yield self` if param
        def import(options = {}, &blk)
          @counter.clear
          if block_given?
            init_client(options)
            output.puts "Importing site..."
            instance_eval(&blk)
            output.puts "Done."
            @counter.each do |k, v|
              output.puts "  + #{v} #{k}"
            end
          else
            import(options) { posts; pages; theme }
          end
        end
        
        def posts(options = {})
          #TODO raise unless client
          ps = client.posts(options)
          output.puts "  #{ps.size} posts found..."
          ps.each do |post| 
            create_post_from post
          end
        end
        
        def pages(options = {})
          #TODO raise unless client
          client.pages(options).each do |page| 
            create_page_from page
          end
        end
        
        def theme(options = {})
          #TODO raise unless client
          create_theme_from client.theme(options)
        end
        
        private
        
        def init_client(options = {})
          
          ::Posterous::Client.resources :post => ::Posterous::Resources::Post
          ::Posterous::Client.resources :page => ::Posterous::Resources::Page
          #TODO the same for Theme
          
          @client = ::Posterous::Client.new(options[:username], options[:password])
          @client.site = options[:site] if options[:site]
          @client.user = options[:user] if options[:user]
          @client.debug_output(options[:debug]) if options[:debug]
          @client
        end
        
        def create_post_from(post)
          output.puts "    #{post.identifier}...extracting media"
          extract_media_from(post)
          output.puts "    #{post.identifier}...updating media tags"
          update_media_tags_in(post)
          output.puts "    #{post.identifier}...creating item in #{identifier_map[:posts]}"
          create_item_from(post, identifier_map[:posts])
          @counter[:posts] += 1
        end
        
        def create_page_from(page)
          output.puts "    #{page.identifier}...extracting media"
          extract_media_from(page)
          output.puts "    #{page.identifier}...updating media tags"
          update_media_tags_in(page)
          output.puts "    #{page.identifier}...creating item in #{identifier_map[:pages]}"
          create_item_from(page, identifier_map[:pages])
          @counter[:pages] += 1
        end
        
        #TODO extract top image from this?
        def create_theme_from(theme)
          create_item_from(theme, identifier_map[:themes])
        end
        
        def extract_media_from(item)
          [:audio_files, :images, :videos].each do |key|
            output.puts "      #{key}...extracting"
            item.send(key).each do |raw| 
              id = create_binary_item_from(raw, identifier_map[key])
              @counter[key] += 1
              output.puts "        #{raw.identifier} => #{id}"
              raw.identifier = id
            end
          end
        end
        
        # TODO split into separate methods per type?
        # or add customizable block methods like
        #      update_images(&blk) which defaults to the below
        def update_media_tags_in(item)
        
          klass = Class.new {
            def initialize(obj); @object = obj; end
            def media; @object; end
            def get_binding; binding(); end
          }

          if images_template
            output.puts "      images...updating tags"
            item.update_images do |tag, img|
              div = tag.parent
              tag.remove
              t = ERB.new(images_template).result(klass.new(img).get_binding)
              div.add_child t
              output.puts "        #{img.identifier} => #{t}"
            end
          end
          
          # TODO for audio_files, videos
        end
        
        # NOTE this is not done now, it assumes site exists
        def create_site_unless_exists
          ::Nanoc3::CLI::Commands::CreateSite.new.run @path, @data_source
          rescue
        end
        
        # NOTE assumes a filesystem_unified data source
        def create_item_from(item, prefix = nil)
          id = "#{prefix}#{item.identifier}".cleaned_identifier
          create_item item.updated_content, item.attributes, id, :extension => '.html'
          id
        end
        
        # NOTE assumes a filesystem_unified data source        
        # This is not ideal, as it ends up reading the content twice, once over http and once locally
        # But Nanoc Filesystem doesn't give us much choice, you have to pass in the content to create_object, not a filename. 
        def create_binary_item_from(item, prefix = nil)          
          id = "#{prefix}#{item.identifier}".cleaned_identifier
          create_item '', item.attributes, id, :extension => '.yaml'
          
          filename_or_io = item.content
          
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

