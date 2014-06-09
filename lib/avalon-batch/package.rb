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
        @manifest.collect { |entry| entry.files }.flatten.collect { |f| File.join(@dir,f[:file]) }
      end

      def complete?
        file_list.all? { |f| File.file?(f) }
      end

      def each_entry
        @manifest.each_with_index do |entry, index|
          files = entry.files.dup
          files.each { |file| file[:file] = File.join(@dir,file[:file]) }
          yield(entry.fields, files, entry.opts, entry, index)
        end
      end

      def processing?
        @manifest.processing?
      end

      def processed?
        @manifest.processed?
      end

      def offset_valid?( offset )
        tokens = offset.split(':')
        return false unless (1...4).include? tokens.size
        seconds = tokens.pop
        return false unless /^\d{1,2}([.]\d*)?$/ =~ seconds
        return false unless seconds.to_f < 60
        unless tokens.empty?
          minutes = tokens.pop
          return false unless /^\d{1,2}$/ =~ minutes
          return false unless minutes.to_i < 60
          unless tokens.empty?
            hours = tokens.pop
            return false unless /^\d{1,}$/ =~ hours
          end
        end
        true
      end

      def initialize_media_object_from_package( entry, user, collection )
        fields = entry.fields.dup
        media_object = MediaObject.new(avalon_uploader: user)
        media_object.workflow.origin = 'batch'
        media_object.collection = collection
        media_object.update_datastream(:descMetadata, fields)
        media_object
      end

      def valid?(current_user,collection)
        @manifest.each do |entry|
          entry.errors.clear
          media_object = initialize_media_object_from_package( entry, current_user.user_key, collection )
          # Set errors if does not validate against media_object model
          media_object.valid?
          media_object.errors.messages.each_pair { |field,errs|
            errs.each { |err| entry.errors.add(field, err) }
          }
          # Sanity check to ensure manifest is not in incorrect collection folder
          if entry.fields[:collection].present? && entry.fields[:collection].first != collection.name
            entry.errors.add(:collection, "The listed collection (#{entry.fields[:collection].first}) does not match the ingest folder name (#{collection.name}).")
          end
          # Check file offsets for valid format
          entry.files.each {|file_spec| entry.errors.add(:offset, "Invalid offset: #{file_spec[:offset]}") if file_spec[:offset].present? && !offset_valid?(file_spec[:offset])}
          # Ensure files are listed
          files = entry.files.collect { |f| File.join( @dir, f[:file]) }
          entry.errors.add(:content, "No files listed") if files.empty?
          # Ensure listed files exist
          files.each_with_index do |f,i| 
            entry.errors.add(:content, "File not found: #{entry.files[i]}") unless File.file?(f)
          end
        end
        @manifest.all? { |entry| entry.errors.count == 0 }
      end

      def process(current_user, collection)
        @manifest.start!
        media_objects = []
        begin
          each_entry do |fields, files, opts, entry, index|

            media_object = initialize_media_object_from_package( entry, current_user.user_key, collection )
            media_object.save( validate: false)
            
            files.each do |file_spec|
              mf = MasterFile.new
              mf.save( validate: false )
              mf.mediaobject = media_object
              mf.setContent(File.open(file_spec[:file], 'rb'))
              mf.absolute_location = file_spec[:absolute_location] if file_spec[:absolute_location].present?
              mf.set_workflow(file_spec[:skip_transcoding] ? 'skip_transcoding' : false)
              mf.label = file_spec[:label] if file_spec[:label].present?
              mf.poster_offset = file_spec[:offset] if file_spec[:offset].present?
              if mf.save
                media_object.save(validate: false)
                mf.process
              end
            end
            
            context = {media_object: { pid: media_object.pid, access: 'private' }, mediaobject: media_object, user: current_user.user_key, hidden: opts[:hidden] ? '1' : nil }
            context = HYDRANT_STEPS.get_step('access-control').execute context
            
            media_object.workflow.last_completed_step = 'access-control'
            
            if opts[:publish]
              media_object.publish!(current_user.user_key)
              media_object.workflow.publish
            end
            
            if media_object.save
              logger.debug "Done processing package #{index}"
            else
              logger.error "Problem saving MediaObject: #{media_object}"
            end
            media_objects << media_object
          end
          @manifest.commit!
        rescue Exception
          @manifest.error!
          raise
        end
        media_objects
      end

      def errors
        Hash[@manifest.collect { |entry| [entry.row,entry.errors] }]
      end
    end
  end
end
