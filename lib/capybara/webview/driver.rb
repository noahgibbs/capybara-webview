# frozen_string_literal: true

require "capybara/webview/wv_connection"
require 'capybara/webview/browser'

class Capybara::Webview::Driver < Capybara::Driver::Base
  attr_reader :app
  attr_reader :options

  def initialize(webview, **options)
    super()

    @wv = webview
    @options = options
  end

  def remote?(url)
    browser.remote?(url)
  end

  #def configure
  #  yield(browser.agent) if block_given?
  #end

  def browser
    @browser ||= Capybara::Webview::Browser.new(self)
  end

  #def reset!
  #  @browser.agent.shutdown
  #  super
  #end

  def response
    browser.last_response
  end

  def request
    browser.last_request
  end

  def visit(path, **attributes)
    browser.visit(path, **attributes)
  end

  def refresh
    browser.refresh
  end

  def submit(method, path, attributes)
    browser.submit(method, path, attributes)
  end

  def follow(method, path, **attributes)
    browser.follow(method, path, attributes)
  end

  def current_url
    browser.current_url
  end

  def response_headers
    response.headers
  end

  def status_code
    response.status
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

  def dom
    browser.dom
  end

  def title
    browser.title
  end

  def reset!
    @browser = nil
  end

  def get(...); browser.get(...); end
  def post(...); browser.post(...); end
  def put(...); browser.put(...); end
  def delete(...); browser.delete(...); end
  def header(key, value); browser.header(key, value); end

end
