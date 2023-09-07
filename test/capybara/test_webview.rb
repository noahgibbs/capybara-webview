# frozen_string_literal: true

require "test_helper"

class Capybara::TestWebview < CapybaraWebviewTest
  def test_that_it_has_a_version_number
    refute_nil ::Capybara::Webview::VERSION
  end

  def test_it_does_something_useful
    webview_process.create_webview_with navigate_dom: "<div id='top'></div>"
  end
end
