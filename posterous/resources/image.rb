# This is a basic Image model for further parsing of Posterous images in Posts and Pages

Dir["#{File.dirname(__FILE__)}/helpers/*.rb"].each do |f|
  require f
end

module Posterous
  module Resources

    class Image
      include Helpers::Identifier
      include Helpers::Downloadable
      
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

      def attributes_proc
        @attributes_proc ||= {}
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
          File.extname(URI.parse(@raw['url']).path.split("/").last.gsub(".#{scale}",''))
      end
      
      def xpath
        ".//img[@src='#{@raw['url']}']"
      end
      
      # via open-uri with progressbar
      def content(to_file = nil)
        @content ||= get_content(@raw['url'], to_file)
      end

      def path
        content.path
      end
      
      def [](attr)
        self.attributes[attr]
      end
      
      def attributes
        @attributes ||= \
          attributes_map.keys.inject({}) do |memo, key|
            if attributes_proc.has_key?(key)
              memo[attributes_map[key]] = attributes_proc[key].call(@raw[key.to_s])
            else
              memo[attributes_map[key]] = @raw[key.to_s]
            end
            memo
          end
      end
                
    end
  
  end
end