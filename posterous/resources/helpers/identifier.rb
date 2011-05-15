module Posterous
  module Resources    
    module Helpers
    
      module Identifier
      
        private
        
        def normalized_identifier(name)
          name.downcase.\
                gsub(/[^a-z\-_]/, '-').\
                gsub(/^-+|-+|-+$/, '-')
        end
        
      end
    
    end
  end
end