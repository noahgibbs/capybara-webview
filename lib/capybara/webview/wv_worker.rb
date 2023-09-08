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

EVAL_RESULT = "wv_capy_return_result"
HEARTBEAT_FUNC = "wv_capy_heartbeat"

# Webview-related helpers

def webview
  return nil if @destroyed

  STDERR.puts "WORKER: CREATE WEBVIEW"
  @webview = WebviewRuby::Webview.new debug: true
  @webview.bind(EVAL_RESULT) do |t, id, val_or_msg|
    conn.send_datagram({t: "bind_call", result: t, id:, val: val_or_msg})
  end
  @webview.bind(HEARTBEAT_FUNC) do
    STDERR.puts "HEARTBEAT"
    conn.instant_read_check
  end
  # The second argument is the time between calls in milliseconds
  @webview.eval("setInterval(#{HEARTBEAT_FUNC},100)")
  @webview
end

def webview_destroy
  STDERR.puts "WORKER: DESTROY WEBVIEW"
  wv = webview
  @destroyed = true
  wv.terminate if wv
  wv.destroy if wv
end

def wrapped_js(js, eval_id)
  id_as_js = JSON.dump eval_id
  <<~JS_CODE
    (function() {
      var code_string = #{JSON.dump js};
      try {
        result = eval(code_string);
        #{EVAL_RESULT}("success", #{id_as_js}, result);
      } catch(error) {
        #{EVAL_RESULT}("error", #{id_as_js}, error.message);
      }
    })();
  JS_CODE
end

conn = WVConnection.new(read, write, :child) do |dgram|
  STDERR.puts "WORKER DATAGRAM: #{dgram.inspect}"

  # We want to make sure certain arguments sent to Webview don't get garbage collected.
  @saved_references = []

  case dgram["t"]
  when "call"
    a = dgram["args"]
    unless a.is_a?(Array)
      raise "Bad 'call' datagram! #{dgram.inspect}"
    end

    case a[0]
    when "init"
      # If we pass init code to Webview, save a reference
      @saved_references << a[1]
    when "bind"
      name = a[1]
      webview.bind(name) { |*args| conn.send_datagram({ t: "bind_call", name:, args: }) }
      next
    when "eval_value"
      # This isn't native webview_ruby functionality. But we can wrap the
      # Javascript we get in quotes, get the value or error, and send it
      # back with the name (identifier) on the Ruby side. Ruby can then
      # call a hook to say "hey, here's the value your Javascript returned."
      #
      # Of course, this won't necessarily catch certain errors, or notice
      # timeouts or just nothing happening, ever. Somebody else will have
      # to handle that.
      webview.eval(wrapped_js(a[1], a[2]))
      next
    end

    webview.send(*a)
  when "kill"
    webview_destroy
    exit 0
  else
    raise "Unrecognized datagram! #{dgram.inspect}"
  end
end

# Start creating a webview immediately on process startup
webview

# Loop for 25 seconds waiting for events, after which we will presumably have called webview.run.
# This is a little weird because webview.run won't return, so generally neither will this.
# That means that later API calls may not be received. That should probably be fixed somehow...
# Should Capybara-Webview register a JS interval callback to check for network input?
conn.event_loop_for(25, increment: 0.1)
