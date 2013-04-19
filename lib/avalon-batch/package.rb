# --- BEGIN LICENSE_HEADER BLOCK ---
# Copyright 2011-2013, The Trustees of Indiana University and Northwestern
#   University.  Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
# 
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software distributed 
#   under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
#   CONDITIONS OF ANY KIND, either express or implied. See the License for the 
#   specific language governing permissions and limitations under the License.
# ---  END LICENSE_HEADER BLOCK  ---

module Avalon
  module Batch
    class Package
      include Enumerable
      extend Forwardable

      attr_reader :dir, :manifest
      def_delegators :@manifest, :each

      def self.locate(root)
        Avalon::Batch::Manifest.locate(root).collect { |f| self.new(f) }
      end

      def initialize(manifest)
        @dir = File.dirname(manifest)
        @manifest = Avalon::Batch::Manifest.new(manifest)
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
        @manifest.start!
        begin
          each_entry do |fields, files, opts, entry|
            yield(fields, files, opts, entry) 
          end
          @manifest.commit!
        rescue Exception
          @manifest.error!
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
