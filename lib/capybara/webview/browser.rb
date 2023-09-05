# frozen_string_literal: true

class Capybara::Webview::Browser
  attr_reader :driver
  attr_reader :current_host

  def initialize(driver)
    @driver = driver
  end

  def app
    driver.app
  end

  def options
    driver.options
  end

  def visit(path, **attributes)
    raise "Implement!"
  end

  def current_url
    raise "Implement!"
  end

  def last_response
    raise "Implement!"
  end

  def last_request
    raise "Implement!"
  end

  def follow(method, path, **attributes)
    raise "Implement!"
  end

  def dom
    raise "Implement!"
  end

  def html
    raise "Implement!"
  end

  # For each of these http methods, we want to intercept the method call.
  # Then we determine if the call is remote or local.
  # Remote: Handle it with our process_remote_request method.
  # Local: Register the local request and call super to let RackTest get it.
  %i[get post put delete].each do |method|
    define_method(method) do |path, params = {}, env = {}, &block|
      raise "Implement!"
    end
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