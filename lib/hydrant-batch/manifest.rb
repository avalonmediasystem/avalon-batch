require 'roo'

module Hydrant
	module Batch
		class Manifest
			include Enumerable

			EXTENSIONS = ['csv','xls','xlsx','ods']
			attr_reader :spreadsheet, :file

			class << self
		  	def locate(root)
		  		possibles = Dir[File.join(root, "**/*.{#{EXTENSIONS.join(',')}}")]
		  		possibles.reject do |file|
		  			File.basename(file) =~ /^~\$/ or self.processing?(file) or self.processed?(file)
		  		end
		  	end

		  	def processing?(file)
					File.file?("#{file}.processing")
		  	end

		 		def processed?(file)
					File.file?("#{file}.processed")
		 		end
		 	end

			def initialize(file)
				@file = file
				@spreadsheet = Roo::Spreadsheet.open(file)
				@field_names = @spreadsheet.row(@spreadsheet.first_row).compact.collect { |field| field.downcase.gsub(/\s/,'_').to_sym }
			end

			def start!
				File.open("#{@file}.processing",'w') { |f| f.puts Time.now.xmlschema }
			end

			def rollback!
				File.unlink("#{@file}.processing")
			end

			def commit!
				File.open("#{@file}.processed",'w') { |f| f.puts Time.now.xmlschema }
				File.unlink("#{@file}.processing")
			end

			def processing?
				self.class.processing?(@file)
			end

			def processed?
				self.class.processed?(@file)
			end

			def each
				f = @spreadsheet.first_row + 1
				l = @spreadsheet.last_row
				f.upto(l) do |index|
					values = @spreadsheet.row(index).collect do |val|
						(val.is_a?(Float) and (val == val.to_i)) ? val.to_i.to_s : val.to_s
					end
					content = values[@field_names.length..-1].join(';').split(/\s*;\s*/)
					fields = Hash[@field_names.zip(values[0..@field_names.length-1])]
					yield({fields: fields, files: content})
				end
			end
		end
	end
end
