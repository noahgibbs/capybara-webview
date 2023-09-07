# Capybara::Webview

Capybara is the standard way to do end-to-end HTML-based testing for your browser-based UI applications. Webview is a lightweight browser-based UI library with relatively limited testing infrastructure. It seems obvious that we should have a Capybara-based interface for Webview.

This driver is incomplete, and doesn't implement some fairly basic pieces of the Capybara interface. It's unlikely to work unmodified for your use case, but it might make a solid start for you.

## Installation

Install the gem and add it to the application's Gemfile by executing:

    $ bundle add capybara-webview

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install capybara-webview

## Usage

You'll want to set up Capybara-Webview in the normal Capybara way:

```ruby
require "capybara/webview"
Capybara.default_driver = :webview
Capybara.run_server = false

# This is for Minitest. Obviously Minitest/spec, RSpec, etc. would be slightly different.
class CapybaraWebviewTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  def teardown
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end
end
```

Then inherit your test classes from `CapybaraWebviewTest`, or whatever you named your own Capybara test parent class. You can set the driver per-test in the normal way.

Webview has a number of options (window size, title, init code, bindings) that can only be set *before* your Webview is running. For that reason, you may wish to have multiple Webview connections. The standard way to do that is to register additional Webview drivers:

```ruby
Capybara.register_driver :webview_plus_options do |app|
  opts = {
    init_code: "console.log('Using webview_plus_options driver');",
    navigate_dom: "<div id='top'></div>",
    title: "Test app!",
    size: [400, 300], # Nil or two-element array [width, height]
    resizeable: true, # Whether to hint to the OS that the window should be resizeable by the user
  }
  Capybara::Webview::Driver.new(app, **opts)
end
```

You can't connect to a Webview in a different process. So if you have an application that uses the Webview, you'll need to use the same remote Webview connection in the application that you use in the tests. Something like this:

```ruby
def test_my_application
  # Get the RPCWebview object, containing a connection to a child process
  wv_connection = page.driver.webview_connection
  start_my_app_with_webview(wv_connection)
end
```

It's possible you may need to restart to get a new clean Webview -- though it would be good to update your tests so you don't need to. But you can call .reset! on the driver manually, which will shut down the child process running Webview and cause it to be re-created when you run the test again:

```ruby
visit '/' # Normally there's a Webview connection
page.driver.reset! # Destroy the Webview connection
visit '/' # The driver creates a new Webview connection
```

## Webview Normally Runs Locally, So How Does This Work?

Webview expects to be run in a process, no more than once, that shuts down when Webview completes. Webview also expects to control the event loop, via `run`, and never give back control for long. It hates background threads and shuts them down on startup. This is not how Capybara tests normally run. However, with some work, we can run Capybara in a compatible mode by starting a subprocess for Webview and using it to relay commands. This is a bit like how Selenium works - we have a manager process wrapped around the actual process running the application under test.

You may need to restart Webview to alter some options (e.g. window init code, JS bindings.) See "Usage" for more details.

## Should You Use Capybara for All Webview Tests?

Capybara is a slow tool, designed for end-to-end integration tests. Each test has substantial startup time, and starting and stopping Webview can take a second or more. By the time you can be confident in the quality of your testing, your tests runs will be unreasonably slow.

Capybara and Webview are not unusual in this! You'll find TDD fans talking about unit testing versus integration testing in many places! Indeed, larger frameworks like Ruby on Rails that tend to run with a browser have this exact same problem. There are a number of good solutions.

The trick to remember is that Webview is your framework, but not all tests need to exercise your framework. Starting a real, literal Webview test is a good thing to do, but it is a slow and awkward way to catch simple errors that creep in day-to-day. By extracting your basic functionality from your framework and running simple fast unit tests, you can catch most errors very rapidly. Then you can have a much smaller number of end-to-end tests that ensure the integration of those small framework-free units of logic with the entire system.

If all your tests are Capybara-based, they are probably far slower than they need to be. Capybara is a slow, powerful, definitive method of end-to-end testing, not the be-all and end-all of your system. Webview is a powerful, difficult, awkward library that does not make itself easy to test. "Test it lots" can be a powerful approach, but it's an expensive one (in developer time, in CPU time, in test stability.) You should use cheaper alternatives wherever they can do the job.

You can see this approach in Rails model testing. By extracting the (fairly fast) models from the (fairly slow) controllers and views and (very slow) Javacript view code, you can run far more tests per minute. And it's common to extract the non-database model logic into a separate class so that you can test it more quickly yet. This is part of the logic for "fat models, skinny controllers" -- move most of your application logic to the location where it's cheapest to test it. If you do this, you wind up with a sort of pyramid of tests. Most of your tests should be plain-Ruby-no-JS-or-DB logic tests without even ActiveRecord. The next level of the pyramid (slower tests, fewer tests) is ActiveRecord-based model tests, then controller tests and view tests using Rack but not a real browser, and finally end-to-end Javascript-capable browser tests using tools like Selenium and Cucumber. The last category is the slowest, the least maintainable, the most fragile, but also the most definitively correct, and should be used sparingly.

Don't eat only ice cream, no matter how good it tastes. Don't use only end-to-end integration tests, no matter how well they prove your whole application works. You need a balanced diet with good variety.

With that said, Webview tests that do ***not*** run Webview are going to be less certain. But they can test their logic ***much*** faster, so you should still use them far more often than "real" Webview tests. They will often be 100x faster or more.

## Developing Capybara-Webview

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/capybara-webview. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/capybara-webview/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Capybara::Webview project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/capybara-webview/blob/main/CODE_OF_CONDUCT.md).
