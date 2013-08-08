[![Gem Version](https://badge.fury.io/rb/transpec.png)](http://badge.fury.io/rb/transpec) [![Dependency Status](https://gemnasium.com/yujinakayama/transpec.png)](https://gemnasium.com/yujinakayama/transpec)

# Transpec

**Transpec** automatically converts your specs into latest [RSpec](http://rspec.info/) syntax with static analysis.

See the following pages for new RSpec syntax:

* [Myron Marston » RSpec's New Expectation Syntax](http://myronmars.to/n/dev-blog/2012/06/rspecs-new-expectation-syntax)
* [RSpec's new message expectation syntax - Tea is awesome.](http://teaisaweso.me/blog/2013/05/27/rspecs-new-message-expectation-syntax/)
* [Myron Marston » The Plan for RSpec 3](http://myronmars.to/n/dev-blog/2013/07/the-plan-for-rspec-3)

## Installation

```bash
$ gem install transpec
```

## Basic Usage

Run `transpec` with no arguments in your project directory:

```bash
$ transpec
```

This will inspect and overwrite all spec files in the `spec` directory.

For more information, please see the help with `--help` option.

**TODO:** Add more description

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
