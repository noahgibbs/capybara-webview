# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "capybara/webview" # includes capybara and capybara/minitest for you
Capybara.default_driver = :webview
Capybara.run_server = false

require "minitest/autorun"
