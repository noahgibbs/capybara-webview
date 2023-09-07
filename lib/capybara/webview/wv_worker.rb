# frozen_string_literal: true

require_relative "wv_connection"
include Capybara::Webview
require "webview_ruby"

if ARGV.size != 2
  raise "Must be invoked as $0 [read_fd] [write_fd]"
end

fd_read, fd_write = Integer(ARGV[0]), Integer(ARGV[1])

read = IO.for_fd(fd_read)
write = IO.for_fd(fd_write)

# Webview-related helpers

def webview
  return nil if @destroyed

  @webview ||= WebviewRuby::Webview.new debug: true
end

def webview_with(
    init_code: nil,
    navigate_dom: nil,
    title: nil,
    size: nil, # Can be a two-element array [width, height]
    resizeable: true)
  # Create the object
  wv = webview

  if init_code
    STDERR.puts "INIT: #{init_code.inspect}"
    @init_code_objects ||= []
    @init_code_objects << init_code
    wv.init(init_code)
  end

  if title
    STDERR.puts "TITLE: #{title.inspect}"
    wv.set_title(title)
  end
  hint = resizeable ? 0 : 3
  if size
    STDERR.puts "SIZE: #{size.inspect}"
    wv.set_size(size[0], size[1], hint)
  end

  if navigate_dom
    STDERR.puts "NAVIGATE: #{navigate_dom.inspect}"
    wv.navigate("data:text/html, #{CGI.escape navigate_dom}")
  end
end

def navigate(dom_html)
  wv.navigate("data:text/html, #{CGI.escape navigate_dom}")
end

def webview_destroy
  wv = webview
  @destroyed = true
  wv.terminate if wv
  wv.destroy if wv
end

conn = WVConnection.new(read, write) do |dgram|
  STDERR.puts "WORKER DATAGRAM: #{dgram.inspect}"
  case dgram["t"]
  when "create"
    kwargs = {}
    dgram["args"].each { |k, v| kwargs[k.to_sym] = v }
    webview_with(**kwargs)
    STDERR.puts "RUN"
    webview.run # Take over the event loop, only return when terminate is called
  when "call"
    a = dgram["args"]
    unless a.is_a?(Array)
      raise "Bad 'call' datagram! #{dgram.inspect}"
    end
    webview.send(*a)
  when "kill"
    webview_destroy
    exit 0
  else
    raise "Unrecognized datagram! #{dgram.inspect}"
  end
end

# Loop for 2.5 seconds waiting for events, after which we will have called webview.run
conn.event_loop_for(2.5, increment: 0.05)
