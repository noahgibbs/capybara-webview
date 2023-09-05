# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

#require "capybara/webview"

require "capybara/webview/outer_minitest"

require "minitest/autorun"

# Capybara-webview is a little weird because you can really only run Webview
# once in a process, and when it shuts down, often your process does too.
# So how do you handle that?
#
# With an outer "runner" test process and an inner Capybara-and-Webview
# process, in our case.
#
# We integrate closely with Minitest in order to run each inner test, then
# use the reported data (assertions, skips, failures) to have the outer
# minitest report properly.

# Things that should be done by the *inner* process:
#
#Capybara.default_driver = :webview
#require "capybara"
#require "capybara/minitest"
#Capybara.run_server = false
