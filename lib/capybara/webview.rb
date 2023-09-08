# frozen_string_literal: true

require_relative "webview/version"
require "capybara"
#require "capybara/minitest"

module Capybara::Webview
  class Error < StandardError; end
end

require "capybara/webview/driver"

Capybara.register_driver :webview do |app|
  STDERR.puts "register_driver: #{app.inspect}"
  Capybara::Webview::Driver.new(app, "size" => [400, 300])
end
