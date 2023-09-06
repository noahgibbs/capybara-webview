# frozen_string_literal: true

require_relative "webview/version"
require "webview_ruby"
require "capybara"
require "capybara/minitest"

require "cgi"

module Capybara::Webview
  class Error < StandardError; end
end

require "capybara/webview/driver"

Capybara.register_driver :webview do |app|
  Capybara::Webview::Driver.new(app)
end

# Capybara and Webview are a bit of an odd combination,
# because Webview really wants to run in its own single-
# use process. We're overriding run_one_method to
# run each Minitest test in its own subprocess.
class MethodChildProcessTest < Minitest::Test
  def worker_fork
    read, write = IO.pipe.each{|io| io.binmode}

    Process.fork do
      read.close

      data = yield

      write.write(Marshal.dump(data))
      write.close
    end
    write.close

    val = Thread.new(read, &:read).value
    Marshal.load val
  end

  def self.run_one_method klass, method_name, reporter
    reporter.prerecord klass, method_name

    # We take the logic of Minitest.run_one_method, and
    # we apply the forking code from minitest-parallel_fork.
    child_result = worker_fork do
      # This happens in a child process, so assigning to a variable doesn't propagate out.
      result = klass.new(method_name).run
      raise "#{klass}#run _must_ return a Result" unless Result === result
      result
    end

    reporter.record child_result
  end
end

class CapybaraWebviewTest < MethodChildProcessTest
  include Capybara::DSL
  include Capybara::Minitest::Assertions

  PARENT_PID = Process.pid

  # We want various helpers for Webview functionality

  def webview
    if Process.pid == PARENT_PID
      STDERR.puts "WARNING: allocating a Webview in the parent process! This is a bad idea!"
    end

    return @webview if @webview

    @init_code_objects ||= []
    @webview = WebviewRuby::Webview.new debug: true
    # @webview.bind("jsFuncName") { blah blah }
    # @webview.init("code goes here")
    # @webview.eval("code goes here")
  end

  def with_webview(
      init_code: nil,
      navigate_dom: nil,
      title: nil,
      size: nil, # Can be a two-element array [width, height]
      resizeable: true,
      &block)
    # Create the object
    wv = webview

    if init_code
      @init_code_objects << init_code
      wv.init(init_code)
    end

    wv.set_title(title) if title
    hint = resizeable ? 0 : 3
    wv.set_size(size[0], size[1], hint) if size

    if navigate_dom
      wv.navigate("data:text/html, #{CGI.escape dom}")
    end

    yield(wv)
    # By default, let teardown handle the webview shutdown
  end

  def teardown
    wv = webview
    wv.terminate if wv
    wv.destroy if wv
  end
end
