require 'tmpdir'

module Hydrant
	module Batch
		class Package
			attr_reader :dir, :manifest

			def initialize(manifest)
				@dir = File.dirname(manifest)
				@manifest = Hydrant::Batch::Manifest.new(manifest)
			end
			
			def file_list
				@manifest.collect { |entry| entry.files }.flatten
			end

		end
	end
end
