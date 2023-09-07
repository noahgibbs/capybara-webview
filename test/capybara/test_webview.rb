# frozen_string_literal: true

require "test_helper"

class Capybara::TestWebview < CapybaraWebviewTest
  def test_that_it_has_a_version_number
    refute_nil ::Capybara::Webview::VERSION
  end

  def test_initial_visit
    visit '/'
    #webview_process.create_webview_with navigate_dom: "<div id='top'></div>"
  end

  def test_it_recreates_a_webview_with_options
    opts = {
      init_code: "true",
      title: "Hello!",
      size: [200, 200],
      resizeable: false,
      navigate_dom: "<div id='top'></div>",
    }
    Capybara.register_driver :webview_single_test_with_options do |app|
      Capybara::Webview::Driver.new(app, **opts)
    end
    Capybara.current_driver = :webview_single_test_with_options
    visit('/')
    page.driver.reset!
    visit('/') # Should recreate the Webview child process, not get an error
    assert_equal({ init_code: "true" }, session.driver.options)
  end

  def test_it_queries_a_dom_object
    page.driver.webview_connection.navigate("<div id='top'></div>")
    visit('/') # how do we want this to work with Webview?
    assert_select("#top")
  end
end
