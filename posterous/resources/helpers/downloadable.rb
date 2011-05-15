
require 'tempfile'
require 'open-uri'
require 'uri'
require 'progressbar'

module Posterous
  module Resources
    module Helpers
    
      module Downloadable
   
        private
        
        def get_content( url, to_file = nil)
        
          to_file ||= Tempfile.new(basename)

          pbar = nil
          open(url,
            :content_length_proc => lambda {|t|
              if t && 0 < t
                pbar = ProgressBar.new(identifier, t)
                pbar.file_transfer_mode
              end
            },
            :progress_proc => lambda {|s|
              pbar.set s if pbar
            }) do |data|
              to_file.write data.read
          end
          to_file.rewind if to_file.respond_to?(:rewind)
          to_file
        
        end
        
      end
      
    end
  end
end