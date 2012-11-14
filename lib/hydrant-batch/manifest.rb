require 'roo'

module Hydrant
	module Batch
		class Manifest
			include Enumerable

			EXTENSIONS = ['csv','xls','xlsx','ods']
			attr_reader :spreadsheet

			def initialize(file)
				@spreadsheet = Roo::Spreadsheet.open(file)
				@field_names = @spreadsheet.row(@spreadsheet.first_row).compact.collect { |field| field.gsub(/\s/,'_').to_sym }
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
