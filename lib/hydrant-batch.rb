require 'active_support/core_ext/array'
require "hydrant-batch/entry"
require "hydrant-batch/manifest"
require "hydrant-batch/package"
require "hydrant-batch/version"

module Hydrant
  module Batch
    class Error < ::Exception; end
    class IncompletePackageError < Error; end

    def self.find_open_files(files, base_directory = '.')
      args = files.collect { |p| %{"#{p}"} }.join(' ')
      Dir.chdir(base_directory) do
        status = `/usr/sbin/lsof -Fcpan0 #{args}`
        statuses = status.split(/[\u0000\n]+/)
        result = []
        statuses.in_groups_of(4) do |group|
          file_status = Hash[group.compact.collect { |s| [s[0].to_sym,s[1..-1]] }]
          if file_status.has_key?(:n) and File.file?(file_status[:n]) and 
            (file_status[:a] =~ /w/ or file_status[:c] == 'scp')
              result << file_status[:n] 
          end
        end
        result
      end
    end

  end
end
