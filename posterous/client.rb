require 'httparty'

# using generic json parser

module Posterous
  class Client
    include HTTParty	

    base_uri 'http://posterous.com/api/2'
    debug_output $stderr

    class HttpError < StandardError
      def initialize(resp)
        # parse message and status from response
      end
    end
    
    def initialize(u, p)
      @auth = {:username => u, :password => p}
    end

    attr_accessor :site, :user
    def site; @site ||= 'primary'; end
    def user; @user ||= 'me'; end

    def posts(options={})
      send_posterous_request :get, "/users/#{user}/sites/#{site}/posts", options
  #		options = {:basic_auth => @auth, :query => posterous_query(options)} 
  #    self.class.get("/users/me/sites/#{site}/posts", options)
    end 

    def pages(options={})
      send_posterous_request :get, "/users/#{user}/sites/#{site}/pages", options
  #		options = {:basic_auth => @auth, :query => posterous_query(options)}
  #    self.class.get("/users/me/sites/#{site}/pages", options)
    end
    
    def theme(options={})
      send_posterous_request :get, "/users/#{user}/sites/#{site}/theme", options
    end

    def sites(options={})
      @sites ||= send_posterous_request :get, "/users/#{user}/sites", options
  #		options = {:basic_auth => @auth, :query => posterous_query(options)} 
  #		@sites ||= self.class.get("/users/me/sites", options)
    end


    def current_user(options={})
      options = {:basic_auth => @auth, :query => options} 
      @user ||= self.class.get("/users/me", options)
    end

    def api_token
      @api_token ||= self.class.get("/auth/token", :basic_auth => @auth)["api_token"]
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

    private

    def posterous_query(options)
      options.merge({'api_token' => api_token})
    end

    def send_posterous_request(verb, path, options = {}, params = {})
      options = {:basic_auth => @auth, :query => posterous_query(params)}
      self.class.send(verb, path, options)
    end
    
  end
  
end
