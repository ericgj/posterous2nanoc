# This is a basic Page model for further parsing of Posterous pages
# Use it by calling
#   Posterous::Client.resources :page => Posterous::Resources::Page

Dir["#{File.dirname(__FILE__)}/helpers/*.rb"].each do |f|
  require f
end

module Posterous
  module Resources

    class Page
      include Helpers::Identifier
      include Helpers::Updatable
      include Helpers::Media
      
      attr_reader :raw
      attr_accessor :identifier
      
      def attributes_map
        @attributes_map ||= \
          {
            'title' => 'title',
            'full_url' => 'posterous_url',
            'id' => 'posterous_post_id',
            'slug' => 'posterous_slug'
          }
      end
      
      def initialize(raw)
        @raw = raw
      end
      
      def identifier
        @identifier ||= normalized_identifier(@raw['title'])
      end
      
      def content
        @content ||= @raw['body']
      end
      
      def [](attr)
        self.attributes[attr]
      end
      
      # note this is not cached, as media_attributes may change
      #
      def attributes
        Hash[attribute_pairs].
          merge(media_attributes)
      end
      
      %w( audio_files images videos).each do |type|
        module_eval(%Q{
          def update_#{type}(&blk)
            self.#{type}.each do |m|
              self.update_each_embed(m, &blk)
            end
          end
        })
      end
      
      private 
                                                
      def attribute_pairs
        (attributes_map.keys).map do |key|
          [ attributes_map[key], @raw[key.to_s] ]
        end
      end
      
    end
  
  end
end