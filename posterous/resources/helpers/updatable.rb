require 'nokogiri'

module Posterous
  module Resources
    module Helpers
    
      module Updatable
      
        attr_accessor :updated_content
        def updated_content; @updated_content ||= self.content; end
        
        def update(&blk)
          @updated_content = \
            Nokogiri::HTML.fragment(
              yield(Nokogiri::HTML.parse(updated_content)).serialize
            ).serialize
        end
        
        def update_each(xpath, &blk)
          dom = Nokogiri::HTML.parse(updated_content)
          dom.xpath(xpath).each do |node|
            yield node
          end
          @updated_content = Nokogiri::HTML.fragment(dom.serialize).serialize
        end
        
        def update_each_embed(item, &blk)
          dom = Nokogiri::HTML.parse(updated_content)
          dom.xpath(item.xpath).each do |node|
            yield node, item
          end
          @updated_content = Nokogiri::HTML.fragment(dom.serialize).serialize
        end
        
      end
      
    end
  end
end