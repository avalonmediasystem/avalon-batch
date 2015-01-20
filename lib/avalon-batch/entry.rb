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
require 'active_model'

module Avalon
  module Batch
    class Entry
    	extend ActiveModel::Translation

    	attr_reader :fields, :files, :opts, :row, :errors, :manifest, :collection

    	def initialize(fields, files, opts, row, manifest)
    		@fields = fields
    		@files  = files
    		@opts   = opts
    		@row    = row
                @manifest = manifest
    		@errors = ActiveModel::Errors.new(self)
                @files.each { |file| file[:file] = File.join(@manifest.package.dir,file[:file]) }
    	end

        def media_object
          @media_object ||= MediaObject.new(avalon_uploader: @manifest.package.user.user_key, 
                                            collection: @manifest.package.collection).tap do |mo|
            mo.workflow.origin = 'batch'
            mo.update_datastream(:descMetadata, fields.dup)
          end
          @media_object
        end

        def valid?
          # Set errors if does not validate against media_object model
          media_object.valid?
          media_object.errors.messages.each_pair { |field,errs|
            errs.each { |err| @errors.add(field, err) }
          }
          # Check file offsets for valid format
          @files.each {|file_spec| @errors.add(:offset, "Invalid offset: #{file_spec[:offset]}") if file_spec[:offset].present? && !Avalon::Batch::Entry.offset_valid?(file_spec[:offset])}
          # Ensure files are listed
          files = @files.collect { |f| f[:file] }
          @errors.add(:content, "No files listed") if files.empty?
          # Ensure listed files exist
          files.each_with_index do |f,i|
            @errors.add(:content, "File not found: #{files[i]}") unless File.file?(f) || !derivativePaths(f).empty?
          end
          # Replace collection error if collection not found
          if media_object.collection.nil?
            @errors.messages[:collection] = ["Collection not found: #{@fields[:collection].first}"]
            @errors.messages.delete(:governing_policy)
          end
        end

        def self.offset_valid?( offset )
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

      def process!
        media_object.save

        @files.each do |file_spec|
          master_file = MasterFile.new
          master_file.save(validate: false) #required: need pid before setting mediaobject
          master_file.mediaobject = media_object
          master_file.absolute_location = file_spec[:absolute_location] if file_spec[:absolute_location].present?
          master_file.set_workflow(file_spec[:skip_transcoding] ? 'skip_transcoding' : false)
          master_file.label = file_spec[:label] if file_spec[:label].present?
          master_file.poster_offset = file_spec[:offset] if file_spec[:offset].present?
          
          master_file.setContent(gatherFiles(file_spec[:file]))
          if master_file.save
            media_object.save(validate: false)
            master_file.process
          end
        end

        context = {media_object: { pid: media_object.pid, access: 'private' }, mediaobject: media_object, user: @manifest.package.user.user_key, hidden: opts[:hidden] ? '1' : nil }
        HYDRANT_STEPS.get_step('access-control').execute context
        media_object.workflow.last_completed_step = 'access-control'

        if opts[:publish]
          media_object.publish!(@manifest.package.user.user_key)
          media_object.workflow.publish
        end

        unless media_object.save
          logger.error "Problem saving MediaObject: #{media_object}"
        end

        media_object
      end

      def gatherFiles(file)
        derivatives = {}
        %w(low medium high).each do |quality|
          derivative = derivativePath(file, quality)
          derivatives["quality-#{quality}"] = File.new(derivative) if File.file? derivative
        end
        derivatives.empty? ? File.new(file) : derivatives
      end

      def derivativePaths(filename)
        paths = []
        %w(low medium high).each do |quality|
          derivative = derivativePath(filename, quality)
          paths << derivative if File.file? derivative
        end
        paths
      end

      def derivativePath(filename, quality)
        filename.dup.insert(filename.rindex('.'), ".#{quality}")
      end
    end
  end
end
