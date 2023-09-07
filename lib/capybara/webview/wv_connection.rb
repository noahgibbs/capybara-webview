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
    def initialize(from, to, &block)
      @from = from
      @to = to
      @on_datagram = block
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
  end

  # We want to run Webview code, but we want not to have to give
  # full control of the event loop to Webview. So instead we
  # run a Webview-based process over a socket, with a simple
  # protocol for API functions.
  class WebviewChildProcess
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

    def parent_connection(r, w)
      @conn = WVConnection.new(r, w) do
      end
    end

    # Parent helpers to send Webview-related commands over a socket

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

    # Send create args as a Hash on the wire, or as keywords in Ruby
    def create_webview_with(**args)
      @conn.send_datagram({t: :create, args: args})
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
