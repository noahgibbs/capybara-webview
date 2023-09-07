# frozen_string_literal: true

require_relative "webview/version"
require "capybara"
require "capybara/minitest"

module Capybara::Webview
  class Error < StandardError; end
end

require "capybara/webview/driver"

Capybara.register_driver :webview do |app|
  STDERR.puts "register_driver: #{app.inspect}"
  Capybara::Webview::Driver.new(app)
end

class CapybaraWebviewTest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions
  include Capybara::Webview

  def webview_process
    return @webview_connection if @webview_connection

    @webview_connection = WebviewChildProcess.new
    @webview_connection.start
    @webview_connection
  end

  # Important to test first: visit, assert_selector

  def teardown
    if @webview_connection
      @webview_connection.kill
      @webview_connection = nil
    end

    Capybara.reset_sessions!
    Capybara.use_default_driver
  end
end
