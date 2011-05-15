# This is a kludge needed until Posterous::Client is gemified...
#
$LOAD_PATH.unshift File.dirname(__FILE__)
require "#{File.dirname(__FILE__)}/nanoc3/extra/importers/posterous.rb"
