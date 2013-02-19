module Hydrant
  module Batch
    class Package
      include Enumerable
      extend Forwardable

      attr_reader :dir, :manifest
      def_delegators :@manifest, :each

      def self.locate(root)
        Hydrant::Batch::Manifest.locate(root).collect { |f| p = self.new(f); p.complete? ? p : nil }.compact
      end

      def initialize(manifest)
        @dir = File.dirname(manifest)
        @manifest = Hydrant::Batch::Manifest.new(manifest)
      end
      
      def title
        File.basename(@manifest.file)
      end

      def file_list
        @manifest.collect { |entry| entry.files }.flatten.collect { |f| File.join(@dir,f) }
      end

      def complete?
        file_list.all? { |f| File.file?(f) }
      end

      def each_entry
        @manifest.each do |entry|
          files = entry.files.collect { |f| File.join(@dir,f) }
          yield(entry.fields, files, entry.opts, entry)
        end
      end

      def processing?
        @manifest.processing?
      end

      def processed?
        @manifest.processed?
      end

      def process
        unless complete?
          raise Hydrant::Batch::IncompletePackageError, "Incomplete Package"
        end

        @manifest.start!
        begin
          each_entry do |fields, files, opts, entry|
            yield(fields, files, opts, entry) 
          end
          @manifest.commit!
        rescue Exception
          @manifest.rollback!
          raise
        end
      end

      def validate
        @manifest.each do |entry|
          entry.errors.clear
          files = entry.files.collect { |f| File.join(@dir,f) }
          validator = yield(entry)
          validator.valid?
          files.each_with_index do |f,i| 
            validator.errors.add(:content, "File not found: #{entry.files[i]}") unless File.file?(f)
          end
          validator.errors.messages.each_pair { |field,errs|
            errs.each { |err| entry.errors.add(field, err) }
          }
        end

        return valid?
      end

      def valid?
        @manifest.all? { |entry| entry.errors.count == 0 }
      end

      def errors
        Hash[@manifest.collect { |entry| [entry.row,entry.errors] }]
      end
    end
  end
end
