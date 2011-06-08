# Edo : a Thor script to backup heroku hosted apps

After several tests and tries with other scripts I've wrotten my own inspired by several ones and ended up writting this Thor based script. It's originaly based on [Carl Hörberg's gist](https://gist.github.com/977203) from [his blog](http://carlhoerberg.com/automatic-backup-of-heroku-database-to-s3).

This script uses a yaml config file to store : heroku and s3 credentials and the names of the apps you want to backup. After that this is pretty straight forward : run it and it will backup your apps.

## How it works

The script start by making a new backup of your app (except if you pass the --old option, then it will use the last one) at Heroku. Then it will get the url, download it locally in a backups folder, and then it will proceed to upload it in a YOURAPPNAME-backup bucket in your S3 account. The bucket suffix can be set in the config.yaml file.

## Get it running

1. Clone the code
2. Get your self a nice ruby env ready (rvm, ruby 1.9.2, bundler)
3. Get the gems : bundle install
4. Set the config : cp config.yaml.sample config.yaml && vim config.yaml
5. Fire it up : bundle exec ruby edo_script.rb backup

## Dependencies

1. Thor : https://github.com/wycats/thor
2. Rvm (optionnal) : http://rvm.beginrescueend.com

You might want to read : https://github.com/wycats/thor to debug or do stuff around with it.

## Fork it

If you have any suggestions or ideas, or just need to adapt the script to your needs make a fork on github : https://github.com/mcansky/edo_script . You can report issues and make pull request through this mean too.

## License

Under MIT license (see LICENSE file).