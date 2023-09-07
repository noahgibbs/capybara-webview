# frozen_string_literal: true

require "test_helper"

class Capybara::TestWebview < CapybaraWebviewTest
  def test_that_it_has_a_version_number
    refute_nil ::Capybara::Webview::VERSION
  end

  def test_it_creates_a_webview
    webview_process.create_webview_with navigate_dom: "<div id='top'></div>"
  end

  def test_it_creates_a_webview_with_options
    webview_process.create_webview_with \
      init_code: "true",
      title: "Hello!",
      size: [200, 200],
      resizeable: false,
      navigate_dom: "<div id='top'></div>"
  end

  def test_it_queries_a_dom_object
    webview_process.create_webview_with navigate_dom: "<div id='top'></div>"
    # visit('/') # is this needed at all with Webview?
    assert_select("#top")
  end
end
