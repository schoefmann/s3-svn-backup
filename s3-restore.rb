#!/usr/bin/env ruby
# File        : s3-restore.rb
# Description : A program to restore svn repositories from 
#               backups made with s3-post-commit.rb
# Copyright   : (c) 2007 Maximilian Schoefmann
# License     : MIT, see the file MIT-LICENSE
%w{rubygems logger base64 sha1 aws/s3}.each{|lib| require lib}
require File.join(File.dirname($0), 's3-config')

LOG = Logger.new(STDOUT)

def usage!
  puts "Usage: #{$0} path/to/new_repo"
  exit 0
end
usage! if ARGV[0] =~ /^(?:-h|--help)$/ || ARGV.empty?

include AWS::S3

def load_dumps!(bucket_name, repo)
  begin
    pattern = /^rev_(\d+)_(\d+).*$/
    prefix = lambda{|p| "rev_#{p}_"}
    rev1 = 0
    while true
      o = Bucket.objects(bucket_name, :prefix => prefix.call(rev1), :max_keys => 1).first
      break unless o
      raise "Unexpected file pattern: #{o.key}" unless pattern.match(o.key)
      rev2 = $2.to_i
      LOG.info "Restoring revisions #{rev1} - #{rev2}"
      dump_file = File.join(WORK_DIR, o.key)
      File.open(dump_file, 'w') do |f|
        o.value do |seg|
          f.write seg
        end
      end
      `#{GUNZIP} -c #{dump_file} | svnadmin load #{repo}`
      s = $?.exitstatus
      raise "'svnadmin load' failed for #{dump_file} with status #{s}" unless s == 0
      File.unlink(dump_file) unless KEEP_FILES
      rev1 = rev2 + 1
    end
  rescue => e
    LOG.fatal e
    exit 1
  end
end

def main(repo)
  connect!
  load_dumps!(full_bucket_name, repo)
end

main(ARGV[0])
