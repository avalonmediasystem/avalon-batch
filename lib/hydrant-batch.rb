require "hydrant-batch/manifest"
require "hydrant-batch/package"
require "hydrant-batch/version"

module Hydrant
  module Batch

    def self.find_open_files(files, base_directory = '.')
	    args = files.collect { |p| %{"#{p}"} }.join(' ')
	    Dir.chdir(base_directory) do
	      status = `/usr/sbin/lsof -Fcpan0 #{args}`
	      statuses = status.split(/[\u0000\n]+/)
	      result = []
	      statuses.in_groups_of(4) do |group|
	      	$stderr.puts group.inspect
	        file_status = Hash[group.collect { |s| [s[0].to_sym,s[1..-1]] }]
	        result << file_status[:n] if (file_status[:a] =~ /w/ or file_status[:c] == 'scp')
	      end
	      result
	    end
    end

  end
end
