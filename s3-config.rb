# File        : s3-config.rb
# Description : Configuration file and helper functions
#               for s3-post-commit.rb and s3-restore.rb
# Copyright   : (c) 2007 Maximilian Schoefmann
# License     : MIT, see the file MIT-LICENSE


##############################################################
# Your settings go here:
# When run as hook-script, subversion will clear out the
# complete environment, hence we need full paths even to gzip

# Your Amazon Key ID
AWS_ID     = 'YOUR_AMAZON_KEY_ID'
# Your secret Amazon Key
AWS_KEY    = 'YOUR_SECRET_AMAZON_KEY'
# The name of the bucket. It will not be used literally, but
# will be prefixed with a Base64-encoded SHA1 hash of your AWS_ID (see #create_bucket_name)
BUCKET     = 'svn-backup'
# The default dir if none is given as command line argument (not for s3-restore)
REPO_DIR   = '/path/to/your/svn-repository'
# Where to write the temporary dump files to
WORK_DIR   = '/path/writable_for_the_svn_user'
# Location of svnadmin and svnlook
SVN_BINDIR = '/usr/local/bin'
# Path to gzip
GZIP       = '/usr/bin/gzip'
# Path to gunzip
GUNZIP     = '/usr/bin/gunzip'
# Where to log the outcome of the backup process
LOG_FILE   = '/path/where_the/logfile_goes/s3-backup.log'
# Set true if dump files shouldn't be deleted
KEEP_FILES = false

##############################################################





# Helper functions for both, s3-restore.rb and s3-post-commit.rb

def full_bucket_name
  "#{Base64.encode64(SHA1.digest(AWS_ID)).gsub(/\W/,'')}-#{BUCKET}"
end

def connect!
  begin
    AWS::S3::Base.establish_connection!(
      :access_key_id     => AWS_ID,
      :secret_access_key => AWS_KEY
    )
    LOG.info "Connection to Amazon established"
  rescue => e
    LOG.fatal e
    exit 1
  end
end
