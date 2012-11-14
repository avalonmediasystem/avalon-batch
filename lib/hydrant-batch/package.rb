module Hydrant
	module Batch
		class Package
			attr_reader :dir, :manifest

			def initialize(manifest)
				@dir = File.dirname(manifest)
				@manifest = Hydrant::Batch::Manifest.new(manifest)
			end
			
			def file_list
				@manifest.collect { |entry| entry[:files] }.flatten.collect { |f| File.join(@dir,f) }
			end

			def complete?
				file_list.all? { |f| File.file?(f) } and Hydrant::Batch.find_open_files(file_list).empty?
			end

			def each_entry &block
				@manifest.each do |entry|
					block.call(entry[:fields], entry[:files])
				end
			end
		end
	end
end
