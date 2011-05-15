# This is a basic Theme model for further parsing of Posterous themes
# Use it by calling
#   Posterous::Client.resources :theme => Posterous::Resources::Theme

Dir["#{File.dirname(__FILE__)}/helpers/*.rb"].each do |f|
  require f
end

module Posterous
  module Resources

    class Theme
      
      attr_reader :raw
      
      def initialize(raw)
        @raw = raw
      end
      
      def content; @content ||= @raw['raw_theme']; end
      
      #TODO resolve 'meta' values in css
      def css
        return @css if @css
        nodes = Nokogiri::HTML.parse(content).xpath('/html/head/style')
        @css = nodes.map(&:content).join("\r\n")
      end
      
      #TODO      
      def favicon
      end
      
    end
    
  end
end