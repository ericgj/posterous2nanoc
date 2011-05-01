require 'httparty'
require 'json'

# using native json parser instead of Crack
class JsonParser < HTTParty::Parser
  def json
		::JSON.parse(body)
  end
end

module Posterous

  class HTTPError < StandardError
    attr :klass, :code, :message, :body
    def initialize(resp)
      @klass = resp.response.class
      @code = resp.code
      @body = resp.body
      @message = resp.parsed_response['error']
    end
    
    def to_s
      "#{klass} (#{code})\n#{message}"
    end
    
  end

  class Client
    include HTTParty	

    base_uri 'http://posterous.com/api/2'
    debug_output $stderr
    parser JsonParser

    class << self
      def resource_map; @resources ||= {}; end
      def resources(map); @resources = map; end
      def resource(entity, klass)
        resource_map[entity.to_sym] = klass
      end
    end
        
    def initialize(u, p)
      @auth = {:username => u, :password => p}
    end

    attr_accessor :site, :user
    def site; @site ||= 'primary'; end
    def user; @user ||= 'me'; end

    def posts(options={})
      raw = send_posterous_request :get, "/users/#{user}/sites/#{site}/posts", options
      resource_for(:post) ? raw.map {|it| as_resource(it, :post)} : raw
    end 

    def pages(options={})
      raw = send_posterous_request :get, "/users/#{user}/sites/#{site}/pages", options
      resource_for(:page) ? raw.map {|it| as_resource(it, :page)} : raw
    end
    
    def theme(options={})
      raw = send_posterous_request :get, "/users/#{user}/sites/#{site}/theme", options
      resource_for(:theme) ? as_resource(raw.parsed_response, :theme) : raw
    end

    def sites(options={})
      return @sites if @sites
      raw = send_posterous_request :get, "/users/#{user}/sites", options
      @sites ||= (resource_for(:site) ? raw.map {|it| as_resource(it, :site)} : raw)
    end

    def current_user(options={})
      return @user if @user
      options = {:basic_auth => @auth, :query => options} 
      raw = send_posterous_request_without_token :get, "/users/me", options
      @user ||= (resource_for(:user) ? as_resource(raw.parsed_response, :user) : raw)
    end

    def api_token
      return @api_token if @api_token
      @api_token ||= send_posterous_request_without_token(
                       :get, "/auth/token", :basic_auth => @auth
                     )["api_token"]
    end

    def user_id
      current_user["id"]
    end

    def post_named(name)
      posts.find {|p| p["name"] = name}
    end

    def posts_tagged(tag)
      posts(:tag => tag)
    end

    def resource_for(entity)
      self.class.resource_map[entity.to_sym]
    end

    def as_resource(resp, entity)
      resource_for(entity).new(resp)
    end
    
    private
    
    def with_token(options)
      options.merge({'api_token' => api_token})
    end

    def send_posterous_request(verb, path, options = {}, params = {})
      send_posterous_request_without_token(verb, path, options, with_token(params))
    end
    
    def send_posterous_request_without_token(verb, path, options = {}, params = {})
      options = {:basic_auth => @auth, :query => params}
      response_or_error self.class.send(verb, path, options)
    end
    
    def response_or_error(resp)
      raise Posterous::HTTPError.new(resp) if resp.code > 399
      resp
    end
    
  end
  
end

# These are basic resource models for further parsing of Posterous data
# Use them by calling e.g. 
#   Posterous::Client.resources :post => Posterous::Resources::Post
#

require 'nokogiri'
#  require 'erb'

module Posterous
  module Resources
    
    module Helpers
    
      def normalized_identifier(name)
        name.downcase.\
              gsub(/[^a-z\-_]/, '-').\
              gsub(/^-+|-+|-+$/, '-')
      end
      
    end
    
    module Updatable
    
      attr_accessor :updated_content
      def updated_content; @updated_content ||= self.content; end
      
      def update(&blk)
        @updated_content = \
          yield(Nokogiri::XML.fragment(updated_content)).serialize
      end
      
      def update_each(xpath, &blk)
        dom = Nokogiri::XML.fragment(updated_content)
        dom.xpath(xpath).each do |node|
          yield node
        end
        @updated_content = dom.serialize
      end
      
    end
    
    class Post
      include Helpers
      include Updatable
       
      attr_reader :raw
      attr_accessor :identifier
      
      def attributes_map
        @attributes_map ||= \
          {
            'title' => 'title',
            'tags' => 'tags',
            'display_date' => 'created_at',
            'full_url' => 'posterous_url',
            'id' => 'posterous_post_id',
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
        @identifier ||= normalized_identifier(@raw['title'])
      end
      
      def content
        @content ||= @raw['body_full']
      end
      
      # note this is not cached, as media_attributes may change
      #
      def attributes
        Hash[
          nontag_attribute_pairs +
          tag_attribute_pairs
        ].merge(media_attributes)
      end

      def media_attributes
        media_attributes_map.keys.inject({}) do |memo, key|
          memo[media_attributes_map[key]] = \
            media[key].map(&:identifier)
          memo
        end
      end
      
      #TODO note this will have to be done separately for each media type
      #
      def media
        @media ||= \
          @raw['media'].inject({}) do |memo, h|
            memo[h.keys[0]] = \
              case h.keys[0] 
              when 'images'
                h[h.keys[0]].map do |img| 
                  img.map do |size, attr|
                    Image.new(size, attr)
                  end
                end.flatten
              else
                []
              end
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
      
      %w( audio_files images videos).each do |type|
        module_eval(%Q{
          def update_#{type}(&blk)
            self.#{type}.each do |m|
              self.update_each(m.xpath, &blk)
            end
          end
        })
      end
      
      private 
                                                
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
      include Helpers
      
      attr_reader :raw, :scale
      attr_accessor :identifier
      
      def attributes_map
        @attributes_map ||= \
          {
            'height' => 'height',
            'width' => 'width',
            'size' => 'size',
            'caption' => 'caption',
            'url' => 'posterous_url',
            'username' => 'posterous_user',
            'post_id' => 'posterous_post_id'
          }
      end
      
      def initialize(scale, raw)
        @scale = scale
        @raw = raw
      end
      
      # Note this is the basic item identifier, without prefix
      # This can be overriden by calling image.identifier=
      def identifier
        @identifier ||= \
          normalized_identifier("#{basename}-#{scale}")
      end
      
      def basename
        @basename ||= \
          File.basename(URI.parse(@raw['url']).path.split("/").last.gsub(".#{scale}",''), '.*')
      end
      
      def extension
        @extension ||= \
          File.extension(URI.parse(@raw['url']).path.split("/").last.gsub(".#{scale}",''))
      end
      
      def xpath
        "//a[@href='#{@raw['url']}'"
      end
      
      # as tempfile - maybe there's a better way?
      def content
        return @content if @content
        f = Tempfile.new(basename)
        #f.unlink
        open(@raw['url']) do |data|
          f.write data.read
        end
        f.rewind
        @content ||= f
      end

      def path
        content.path
      end
      
      def attributes
        @attributes ||= \
          attributes_map.keys.inject({}) do |memo, key|
            memo[attributes_map[key]] = @raw[key]
            memo
          end
      end
                
    end
    
    
    #TODO Video, Audio, Page, Theme classes
  
  end
end
