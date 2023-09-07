# frozen_string_literal: true

require "capybara/webview/wv_connection"
require 'capybara/webview/browser'

class Capybara::Webview::Driver < Capybara::Driver::Base
  # attr_writer :session # in parent class

  attr_reader :app
  attr_reader :options

  def initialize(app = nil, **options)
    STDERR.puts "WV Driver init: #{app.inspect} #{options.inspect}"

    super()

    @app = app # should normally always be nil
    @options = options
  end

  def webview_connection
    browser.conn
  end

  def browser
    @browser ||= Capybara::Webview::Browser.new(self)
  end

  def set_content(html)
    browser.set_content(html)
  end

  # Capybara::Driver::Base methods

  def current_url
    STDERR.puts "CURRENT URL"
    browser.current_url
  end

  def visit(path, **attributes)
    STDERR.puts "VISIT: #{path.inspect} #{attributes.inspect}"
    browser.visit(path, **attributes)
  end

  def refresh
    STDERR.puts "REFRESH"
    browser.refresh
  end

  def find_xpath(selector)
    browser.find(:xpath, selector)
  end

  def find_css(selector)
    browser.find(:css, selector)
  rescue Nokogiri::CSS::SyntaxError
    raise unless selector.include?(' i]')

    raise ArgumentError, "This driver doesn't support case insensitive attribute matching when using CSS base selectors"
  end

  def html
    browser.html
  end

  # Default to not implemented, leave it not implemented
  #def go_back
  #end
  #def go_forward
  #end

  # We could do this, but for now leave unimplemented
  #def execute_script
  #end
  #def evaluate_script
  #end
  #def evaluate_async_script
  #end
  #def save_screenshot
  #end

  # Remove these?
  def response_headers
    response.headers
  end
  def status_code
    response.status
  end

  # We could do this, but for now leave unimplemented
  #def send_keys
  #end
  #def active_element
  #end

  # Default to not implemented, leave it not implemented
  #def switch_to_frame
  #end
  #def frame_title
  #end
  #def frame_url
  #end
  #def current_window_handle
  #end
  #def window_size
  #end
  #def resize_window_to
  #end
  #def maximize_window
  #end
  #def fullscreen_window
  #end
  #def close_window
  #end
  #def window_handles
  #end
  #def open_new_window
  #end
  #def switch_to_window
  #end
  #def no_such_window_error
  #end

  # We could do this, but for now leave unimplemented
  #def accept_modal
  #end
  #def dismiss_modal
  #end

  # This is a list of error types that count as "invalid element"
  def invalid_element_errors
    []
  end

  def wait?
    STDERR.puts "wait?"
    false
  end

  # Make sure state has been cleaned up
  def reset!
    browser.reset!
    super
  end
end
