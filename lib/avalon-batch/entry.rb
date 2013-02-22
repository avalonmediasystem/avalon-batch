module Avalon
  module Batch
    class Entry
    	extend ActiveModel::Translation

    	attr_reader :fields, :files, :opts, :row, :errors

    	def initialize(fields, files, opts, row)
    		@fields = fields
    		@files  = files
    		@opts   = opts
    		@row    = row
    		@errors = ActiveModel::Errors.new(self)
    	end

    end
  end
end

