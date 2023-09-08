# frozen_string_literal: true

require "socket"
require "json"
require "cgi"
require "rbconfig"

# Must be able to be required *without* the rest of Capybara-Webview by wv_worker.rb

module Capybara; end
module Capybara::Webview
  class SocketError < StandardError; end

  # A socket-based connection for sending datagrams back and forth.
  # The Webview-over-socket connection uses two of these, one each
  # in the parent and child process.
  class WVConnection
    attr_reader :msgs_written
    attr_reader :msgs_read

    def initialize(from, to, i_am, &block)
      @from = from
      @to = to
      @on_datagram = block
      @i_am = i_am

      @msgs_written = 0
      @msgs_read = 0
    end

    # Checks whether the internal socket is ready to be read from.
    # If timeout is greater than 0, this will block for up to that long.
    #
    # @param timeout [Float] the longest to wait for more input to read
    # @return [Boolean] whether the socket has data ready for reading
    def ready_to_read?(timeout = 0.0)
      r, _, e = IO.select [@from], [], [@from, @to].uniq, timeout

      # On timeout, select returns nil instead of arrays.
      return if r.nil?

      unless e.empty?
        raise "#{@i_am}: Got error on connection(s) from IO.select! Dying!"
      end

      !r.empty?
    end

    # Send bytes on the internal socket to the opposite side.
    #
    # @param contents [String] data to send
    # @return [void]
    def send_datagram(contents)
      STDERR.puts "RAW SEND (#{@i_am}): #{contents.inspect}"
      str_data = JSON.dump contents
      dgram_str = (str_data.length.to_s + "a" + str_data).encode(Encoding::BINARY)
      to_write = dgram_str.bytesize
      written = 0

      until written == to_write
        count = @to.write(dgram_str.byteslice(written..-1))
        if count.nil? || count == 0
          raise "Something was wrong in send_datagram! Write returned #{count.inspect}!"
        end

        written += count
      end

      @msgs_written += 1

      nil
    end

    # Read data from the internal socket. Read until a whole datagram
    # has been received and then return it.
    #
    # @return [String] the received datagram
    def receive_datagram
      @readbuf ||= String.new.encode(Encoding::BINARY)
      to_read = nil

      loop do
        # Have we read a packet length already, sitting in @readbuf?
        a_idx = @readbuf.index("a")
        if a_idx
          to_read = @readbuf[0..a_idx].to_i
          @readbuf = @readbuf[(a_idx + 1)..-1]
          break
        end

        # If not, read more bytes
        new_bytes = @from.read(10)
        if new_bytes.nil?
          # This is perfectly normal, if the connection closed
          raise SocketError, "Got an unexpected EOF reading datagram! " +
            "Did the #{@i_am == :child ? "parent" : "child"} process die?"
        end
        @readbuf << new_bytes
      end

      loop do
        if @readbuf.bytesize >= to_read
          out = @readbuf.byteslice(0, to_read)
          @readbuf = @readbuf.byteslice(to_read, -1)
          STDERR.puts "RAW READ (#{@i_am}): #{out.inspect}"
          @msgs_read += 1
          return out
        end

        new_bytes = @from.read(to_read - @readbuf.bytesize)
        @readbuf << new_bytes
      end
    rescue
      raise SocketError, "Got exception #{$!.class} when receiving datagram... #{$!.inspect}"
    end

    # Read a datagram from the internal buffer and then dispatch it to the
    # appropriate handler.
    def respond_to_datagram
      message = receive_datagram
      m_data = JSON.parse(message)

      @on_datagram.call(m_data)
    end

    # Loop for up to `t` seconds, reading data and waiting.
    #
    # @param t [Float] the number of seconds to loop for
    def event_loop_for(t = 1.5, increment: 0.1)
      t_start = Time.now
      delay_time = t

      while !delay_time || (Time.now - t_start < delay_time)
        if ready_to_read?(0.1)
          respond_to_datagram
        else
          sleep increment
        end
      end
    end

    # Dispatch datagrams while there's data available, but don't wait for any more.
    def instant_read_check
      respond_to_datagram while ready_to_read?(0.0)
    end
  end

  # We want to run Webview code, but we want not to have to give
  # full control of the event loop to Webview. So instead we
  # run a Webview-based process over a socket, with a simple
  # protocol for API functions.
  #
  # This object can impersonate a Webview for most purposes
  # once it's created and running. But calls are sent over
  # the socket and results are returned.
  class RPCWebview
    def start
      read1, write1 = IO.pipe
      read2, write2 = IO.pipe

      STDERR.puts "SPAWN"
      rfd = read2.fileno
      wfd = write1.fileno
      @child_pid = Kernel.spawn \
        RbConfig.ruby, File.expand_path(File.join __dir__, "wv_worker.rb"), rfd.to_s, wfd.to_s,
        { rfd => rfd, wfd => wfd } # pass pipe to child process

      read2.close
      write1.close

      parent_connection(read1, write2)
      nil
    end

    # See if anything has arrived
    def msg_check(duration: 0.05, increment: 0.1)
      if duration == 0.0
        @conn.instant_read_check
      else
        @conn.event_loop_for(duration, increment:)
      end
    end

    def wait_for_startup(timeout: 15)
      t_start = Time.now

      STDERR.puts "WAIT FOR STARTUP"
      while Time.now - t_start < timeout
        @conn.event_loop_for(0.5)
        break if @conn.msgs_read > 0  # Have we read a message yet?
      end
      STDERR.puts "WAIT FOR STARTUP: FINISHED #{@conn.msgs_read > 0 ? "SUCCESSFULLY" : "UNSUCCESSFULLY"}"
    end

    private

    def parent_connection(r, w)
      @bind_mapping = {}

      @conn = WVConnection.new(r, w, :parent) do |dgram|
        STDERR.puts "Parent received: #{dgram.inspect}"
        if dgram["t"] == "bind_call"
          raise "Implement!"
        end
      end
    end

    public

    # Parent helpers to send Webview-related commands over a socket

    def navigate(page)
      @conn.send_datagram({t: :call, args: ["navigate", page]})
    end

    def set_title(title)
      @conn.send_datagram({t: :call, args: ["set_title", title]})
    end

    def set_size(width, height, hint=0)
      @conn.send_datagram({t: :call, args: ["set_size", width, height, hint]})
    end

    def run
      @conn.send_datagram({t: :call, args: ["run"]})
    end

    def bind(name, func = nil, &block)
      @bind_mapping[name] = if func
        proc { |params| func(*params) }
      else
        proc { |params| block.call(*params) }
      end
      @conn.send_datagram({t: :call, args: ["bind", name]})
    end

    def init(js)
      @conn.send_datagram({t: :call, args: ["init", js]})
    end

    def eval(js)
      @conn.send_datagram({t: :call, args: ["eval", js]})
    end

    def gen_name
      @ctr ||= 0
      @ctr += 1
      "wv_capy_binding_%05d" % @ctr
    end

    # Webview_ruby doesn't do this, but we can. Eval the code
    # and call the supplied block with the value when it arrives.
    def eval_value(js, &block)
      n = gen_name
      @bind_mapping[n] = proc { |params| block.call(params[0]) }
      @conn.send_datagram({t: :call, args: ["eval_value", js, n]})
    end

    # Don't wait to separate terminate from destroy. If we get either, shut everything down.
    def terminate
      kill
    end

    def destroy
      kill
    end

    def kill
      if @child_pid
        @conn.send_datagram({t: :kill})
        Process.wait @child_pid, Process::WNOHANG
        sleep 0.5 # TODO: loop instead of static wait
        Process.kill "KILL", @child_pid
        Process.wait @child_pid, 0
        @child_pid = nil
      end
    end

    # Example commands:
    # @webview.bind("jsFuncName") { blah blah }
    # @webview.init("code goes here")
    # @webview.eval("code goes here")

    def cmd(*args)
      @conn.send_datagram({t: :call, args: args})
    end
  end
end
