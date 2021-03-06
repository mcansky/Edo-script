#!/bin/env ruby

require "rubygems"
require "bundler/setup"

# get all the gems in
Bundler.require(:default)

require "heroku/command"
require 'heroku/command/auth'
require "heroku/command/pgbackups"
require "open-uri"

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
  method_options :app => :string
  def backup
    # load config
    config = YAML.load_file(File.expand_path(File.dirname(__FILE__)) + "/config.yaml")
    active_path = File.expand_path(File.dirname(__FILE__))
    Dir.mkdir(active_path + "/backups/") unless File.exist?(active_path + "/backups/")
    apps = Array.new
    if not options[:app]
	apps = config["heroku"]["apps"]
    else
        apps << options[:app]
    end
    apps.each do |heroku_app|
      backup_bucket = "#{heroku_app}-#{config["s3"]["bucket_suffix"]}"
      file_name = "#{heroku_app}-backup-#{Time.now.strftime(config['s3']['timestamp'])}.dump"
      file_path = File.expand_path(File.dirname(__FILE__)) + "/backups/" + file_name
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
      url.chomp!
      say "\tDowloading localy", :green
      File.open(file_path, "w") do |file|
        file << open(url).read
      end
      puts "backup : #{url.chomp} to be saved at #{file_name}"
      puts "\tUploading to S3..."
      s3 = Aws::S3.new(config["s3"]["token"], config["s3"]["secret"])
      bucket = Aws::S3::Bucket.create(s3, backup_bucket)
      key = Aws::S3::Key.create(bucket, file_name)
      if key.exists?
        say "Backup for #{heroku_app} @ #{Time.now.strftime('%Y%m%d_%H%M')} already exists !", :yellow
      else
        key.put(IO.read(active_path + "/backups/" + file_name))
        key.exists? ? say("Backup for #{heroku_app} @ #{Time.now.strftime('%y%m%d_%H%M')} uploaded !", :green) : say("Backup for #{Time.now.strftime('%y%m%d_%H%M')} had trouble !", :red)
      end
      say "Done @ #{Time.now}", :green
    end
  end
end

Edo.start
