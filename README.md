# SmsBackupRenderer

This tool reads backup files created by [SMS Backup & Restore](https://www.carbonite.com/en/apps/call-log-sms-backup-restore) and generates static HTML files for viewing their contents.

It supports both SMS and MMS messages, including images and videos.
It attempts to create readable conversation-style views.

(I am not affiliated with Carbonite in any way.)

## Installation

    $ gem install sms_backup_renderer

## Usage

    $ sms_backup_renderer PATH_TO_XML_ARCHIVE PATH_TO_OUTPUT_DIRECTORY

I suggest creating a new, empty directory to use as the output directory the first time you run this, since multiple files and subdirectories will be created within it.

After the command runs, the output directory will contain an `index.html` file you can open in your browser.

## Caveats

The backup files may represent the same number in different ways (e.g `+1 (234) 567-8901` and `2345678901`) at different times.
In order to group all messages for the same number into the same conversation, `sms_backup_renderer` must try to normalize the numbers into a consistent format.
Currently, the way this is done is pretty hacky and only knows about the US country code.
Non-US numbers might be grouped incorrectly in some cases.

Determining the contact names for group MMS messages also relies on some pretty hacky code.
It probably won't work right if you have contact names containing commas.
It may not work right anyway - I'm not sure if the assumptions it makes about the backup archive are always true, or if they are coincidental implementation details that may be affected by the messaging software on your phone.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/sms_backup_renderer.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

