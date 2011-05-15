# This is a basic Post model for further parsing of Posterous posts
# Use it by calling
#   Posterous::Client.resources :post => Posterous::Resources::Post

Dir["#{File.dirname(__FILE__)}/helpers/*.rb"].each do |f|
  require f
end

module Posterous
  module Resources

    class Post
      include Helpers::Identifier
      include Helpers::Updatable
      include Helpers::Media
       
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
      
      def initialize(raw)
        @raw = raw
      end
      
      def identifier
        @identifier ||= normalized_identifier(@raw['title'])
      end
      
      def content
        @content ||= @raw['body_full']
      end
      
      def [](attr)
        self.attributes[attr]
      end
      
      # note this is not cached, as media_attributes may change
      #
      def attributes
        Hash[nontag_attribute_pairs].
             merge('tags' => tags).
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
      
      def tags
        @tags ||= @raw['tags'].map {|t| t['name']} 
      end
      
      private 
                                                
      def nontag_attribute_pairs
        (attributes_map.keys - ['tags']).map do |key|
          [ attributes_map[key], @raw[key.to_s] ]
        end
      end
      
      # no longer used
      def tag_attribute_pairs
        [ attributes_map['tags'], @raw['tags'].map {|t| t['name']} ]
      end
                
    end
  
  end
end