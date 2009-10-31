#!/usr/bin/env ruby
# File        : s3-post-commit.rb
# Description : A program to create svn backups using the
#               Amazons S3 storage service
# Copyright   : (c) 2007 Maximilian Schoefmann
# License     : MIT, see the file MIT-LICENSE
%w{rubygems logger base64 sha1 aws/s3}.each{|lib| require lib}
require File.join(File.dirname($0), 's3-config')

LOG = Logger.new(LOG_FILE)

def usage!
  puts "Usage: #{$0} [path/to/repo [revision]]"
  exit 0
end
usage! if ARGV[0] =~ /^(?:-h|--help)$/

repo = ARGV[0] || REPO_DIR
rev  = (ARGV[1] || `#{SVN_BINDIR}/svnlook youngest #{repo}`.strip).to_i

include AWS::S3

# returns -1 when no revision was found
def find_last_rev(bucket)
  # Pattern of the S3Object-keys
  pattern = /^rev_(\d+)_(\d+).*$/
  rev = -1
  # S3Objects can come theoretically in any order...
  bucket.each do |o|
    if o.key.match(pattern)
      rev = $2.to_i if $2.to_i > rev
    end
  end
  rev
end

# creates an incremental/delta/gzipped dump from rev1 to rev2
def dump_repository(repo, rev1, rev2)
  dump_file = File.join(WORK_DIR, "rev_#{rev1}_#{rev2}.dump.gz")
  `#{SVN_BINDIR}/svnadmin dump #{repo} --incremental --deltas -q -r #{rev1}:#{rev2} | #{GZIP} -f >#{dump_file}`
  if !FileTest.exist?(dump_file) || $?.exitstatus != 0
    LOG.fatal "'svnadmin dump' to file #{dump_file} failed"
    exit 1
  end
  dump_file
end

def write_to_s3!(file, bucket_name)
  begin
    S3Object.store(
      File.basename(file),
      open(file),
      bucket_name
    )
  rescue => e
    LOG.fatal e
    exit 1
  end
end

def main(repo, rev)
  connect!
  bucket_name = full_bucket_name
  begin
    bucket = Bucket.find(bucket_name)
  rescue NoSuchBucket
    LOG.info "Creating new bucket #{bucket_name}"
    Bucket.create(bucket_name)
    bucket = Bucket.find(bucket_name)
  end
  next_rev = find_last_rev(bucket) + 1
  if next_rev > rev
    LOG.warn "Last backup is of revision #{next_rev}, current revision is #{rev} - Aborting"
    exit 0
  end
  dump_file = dump_repository(repo, next_rev, rev)
  write_to_s3!(dump_file, bucket_name)
  LOG.info "Backup of revisions #{next_rev} to #{rev} finished"
  File.unlink(dump_file) unless KEEP_FILES
end

main(repo, rev)
