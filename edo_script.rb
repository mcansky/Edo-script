#!/bin/env ruby

require "rubygems"
require "thor"
require "aws"
require "bundler/setup"
require "heroku/command"
require 'heroku/command/auth'
require "heroku/command/pgbackups"
#require "/usr/local/rvm/rubies/ruby-1.9.2-p180/lib/ruby/1.9.1/net/https.rb"

module Kernel
  def capture_stdout
    out = StringIO.new
    $stdout = out
    yield
    return out.string
  ensure
    $stdout = STDOUT
  end
end

class Edo < Thor
  class Heroku::Auth
    def self.client
      config = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + "/config.yaml")
      Heroku::Client.new(config["heroku"]["user"], config["heroku"]["password"])
    end
  end

  include Thor::Actions
  
  desc "backup", "backup apps datas"
  method_options :old => false
  def backup
    # load config
    config = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + "/config.yaml")
    active_path = File.expand_path(File.dirname(__FILE__))
    Dir.mkdir(active_path + "/backups/") unless File.exist?(active_path + "/backups/")
    config["heroku"]["apps"].each do |heroku_app|
      backup_bucket = "#{heroku_app}-#{config["s3"]["bucket_suffix"]}"
      file_name = "backup-#{Time.now.strftime(config['s3']['timestamp'])}.dump"
      say "Backup for #{heroku_app} started @ #{Time.now}", :green
      if not options[:old]
        say "\tTriggering backup at Heroku ...", :green
        Heroku::Command.run 'pgbackups:capture', ['--expire', '--app', heroku_app]
      else
        say "\tUsing last backup as requested ...", :yellow
      end
      say "\tGetting backup url ...", :green
      url = capture_stdout do
        Heroku::Command.run 'pgbackups:url', ['--app', heroku_app]
      end
      say "\tDowloading localy", :green
      system("curl -o backups/#{file_name} '#{url}'")
      puts "\tUploading to S3..."
      s3 = Aws::S3.new(config["s3"]["token"], config["s3"]["secret"])
      bucket = Aws::S3::Bucket.create(s3, backup_bucket)
      key = Aws::S3::Key.create(bucket, file_name)
      if key.exists?
        say "Backup for #{heroku_app} @ #{Time.now.strftime('%Y%m%d_%H%M')} already exists !", :yellow
      else
        key.put(IO.read("backups/" + file_name))
        key.exists? ? say("Backup for #{heroku_app} @ #{Time.now.strftime('%y%m%d_%H%M')} uploaded !", :green) : say("Backup for #{Time.now.strftime('%y%m%d_%H%M')} had trouble !", :red)
      end
      say "Done @ #{Time.now}", :green
    end
  end
end

Edo.start