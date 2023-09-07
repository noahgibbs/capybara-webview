# frozen_string_literal: true

require "nokogiri"

# Browser, unlike Driver, is an implementation detail and we can change or skip it as we
# like. For now, it's here in this very rough form.
module Capybara::Webview
  class Browser
    attr_reader :driver
    attr_reader :current_url

    def initialize(driver)
      @driver = driver
      @current_url = '/'
    end

    def webview_connection
      return @webview_connection if @webview_connection

      @webview_connection = WebviewChildProcess.new
      @webview_connection.start
      @webview_connection
    end

    def app
      driver.app
    end

    def options
      driver.options
    end

    def set_content(html)
      raise "Implement!"
    end

    def visit(path, **attributes)
      raise "Implement!"
    end

    def dom
      raise "Implement!"
    end

    def html
      raise "Implement!"
    end

    def refresh
      raise "Implement!"
    end

    def find(format, selector)
      raise "Implement!"
      if format == :css
        dom.css(selector, Capybara::RackTest::CSSHandlers.new)
      else
        dom.xpath(selector)
      end.map { |node| Capybara::Mechanize::Node.new(self, node) }
    end
  end
end