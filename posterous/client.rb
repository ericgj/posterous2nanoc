require 'httparty'
require 'json'
Dir["#{File.dirname(__FILE__)}/resources/*.rb"].each do |f|
  require f
end

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
    #debug_output $stderr
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
      raw = send_posterous_request :get, "/users/#{user}/sites/#{site}/posts", {}, options
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

