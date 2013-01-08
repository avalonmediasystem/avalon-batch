require 'roo'

module Hydrant
  module Batch
    class Manifest
      include Enumerable

      EXTENSIONS = ['csv','xls','xlsx','ods']
      attr_reader :spreadsheet, :file, :name, :email

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
        @name = @spreadsheet.row(@spreadsheet.first_row)[0]
        @email = @spreadsheet.row(@spreadsheet.first_row)[1]
        @field_names = @spreadsheet.row(@spreadsheet.first_row + 1).collect { |field| 
          field.to_s.downcase.gsub(/\s/,'_').strip.to_sym 
        }.select { |f| not f.empty? }
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
        f = @spreadsheet.first_row + 2
        l = @spreadsheet.last_row
        f.upto(l) do |index|
          values = @spreadsheet.row(index).collect do |val|
            (val.is_a?(Float) and (val == val.to_i)) ? val.to_i.to_s : val.to_s
          end
          content = values[@field_names.length..-1].join(';').split(/\s*;\s*/)
          fields = Hash.new { |h,k| h[k] = [] }
          @field_names.each_with_index { |f,i| fields[f] << values[i] unless values[i].blank? }
          fields[:publish] = (not (fields[:publish].first.to_s =~ /^(y(es)?|t(rue)?)$/i).nil?)
          yield({fields: fields, files: content})
        end
      end
    end
  end
end
