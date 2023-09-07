# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "capybara/webview" # includes capybara and capybara/minitest for you
require "capybara/minitest"
Capybara.default_driver = :webview
Capybara.run_server = false

require "minitest/autorun"

class CapybaraWebviewTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions
  #include Capybara::Webview

  def teardown
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end
end
