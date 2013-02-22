require 'roo'

module Avalon
  module Batch
    class Manifest
      include Enumerable
      extend Forwardable

      EXTENSIONS = ['csv','xls','xlsx','ods']
      def_delegators :@entries, :each
      attr_reader :spreadsheet, :file, :name, :email, :entries

      class << self
        def locate(root)
          possibles = Dir[File.join(root, "**/*.{#{EXTENSIONS.join(',')}}")]
          possibles.reject do |file|
            File.basename(file) =~ /^~\$/ or self.error?(file) or self.processing?(file) or self.processed?(file)
          end
        end

        def error?(file)
          if File.file?("#{file}.error")
            if File.mtime(file) > File.mtime("#{file}.error")
              File.unlink("#{file}.error")
              return false
            else
              return true
            end
          end
          return false
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
        load!
      end

      def load!
        @entries = []
        @spreadsheet = Roo::Spreadsheet.open(file)
        @name = @spreadsheet.row(@spreadsheet.first_row)[0]
        @email = @spreadsheet.row(@spreadsheet.first_row)[1]
        @field_names = @spreadsheet.row(@spreadsheet.first_row + 1).collect { |field| 
          field.to_s.downcase.gsub(/\s/,'_').strip.to_sym 
        }.select { |f| not f.empty? }
        create_entries!
      end

      def start!
        File.open("#{@file}.processing",'w') { |f| f.puts Time.now.xmlschema }
      end

      def error!
        File.open("#{@file}.error",'w') do |f| 
          entries.each do |entry|
            if entry.errors.count > 0
              f.puts "Row #{entry.row}:"
              entry.errors.messages.each { |k,m| f.puts %{  #{m.join("\n  ")}} }
            end
          end
        end
        rollback! if processing?
      end

      def rollback!
        File.unlink("#{@file}.processing")
      end

      def commit!
        File.open("#{@file}.processed",'w') { |f| f.puts Time.now.xmlschema }
        rollback! if processing?
      end

      def error?
        result = self.class.error?(@file)
        load! unless result
        result
      end

      def processing?
        self.class.processing?(@file)
      end

      def processed?
        self.class.processed?(@file)
      end

      def errors
        @errors ||= []
      end

      private
      def create_entries!
        f = @spreadsheet.first_row + 2
        l = @spreadsheet.last_row
        f.upto(l) do |index|
          opts = {
            :publish => false,
            :hidden  => false
          }

          values = @spreadsheet.row(index).collect do |val|
            (val.is_a?(Float) and (val == val.to_i)) ? val.to_i.to_s : val.to_s
          end
          content = values[@field_names.length..-1].join(';').split(/\s*;\s*/)
          fields = Hash.new { |h,k| h[k] = [] }
          @field_names.each_with_index { |f,i| fields[f] << values[i] unless values[i].blank? }

          opts.keys.each { |opt|
            val = Array(fields.delete(opt)).first.to_s
            if opts[opt].is_a?(TrueClass) or opts[opt].is_a?(FalseClass)
              opts[opt] = (not (val =~ /^(y(es)?|t(rue)?)$/i).nil?)
            else
              opts[opt] = val
            end
          }

          entries << Entry.new(fields, content, opts, index)
        end
      end

    end
  end
end
