module Posterous
  module Resources
    module Helpers
    
      module Media

        def media_attributes_map
          @media_attributes_map ||= \
            {
              'audio_files' => 'audio',
              'videos' => 'video',
              'images' => 'images',
            }
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
                      ::Posterous::Resources::Image.new(size, attr)
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
        
      end
    end
  end
end