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

			def each_entry
				@manifest.each do |entry|
					yield(entry[:fields], entry[:files])
				end
			end

			def processing?
				@manifest.processing?
			end

			def processed?
				@manifest.processed?
			end

			def process
				@manifest.start!
				begin
					unless complete?
						raise Hydrant::Batch::IncompletePackageError, "Incomplete Package"
					end
					each_entry do |fields, files| 
						yield(fields, files) 
					end
					@manifest.commit!
				rescue
					@manifest.rollback!
					raise
				end
			end

		end
	end
end
