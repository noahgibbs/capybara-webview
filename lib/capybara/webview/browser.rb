# frozen_string_literal: true

require "nokogiri"

# Browser, unlike Driver, is an implementation detail and we can change or skip it as we
# like. For now, it's here in this very rough form.
module Capybara::Webview
  class Browser
    attr_reader :driver
    attr_reader :current_url

    # By default, wait up to 2.5 seconds for the remote Webview to respond to things
    DEFAULT_WAIT = 2.5

    def initialize(driver)
      @driver = driver
      @current_url = '/'

      @visit_id = 0
    end

    def conn
      if @conn
        conn_check # We need a connection? Make sure it's up to date on dispatching incoming messages
        return @conn
      end

      # No connection - need to set it up
      STDERR.puts "CONN CREATE"
      @conn = RPCWebview.new
      @conn.start

      opts = driver.options

      if opts["size"]
        hint = 3 # Default is resizeable
        hint = 0 if opts.key?("resizeable") && !opts["resizeable"]
        width, height = *opts["size"]

        @conn.set_size(width, height, hint)
      end

      @conn.set_title(opts["title"]) if opts["title"]
      @conn.init(init_code) if opts["init_code"]
      @conn.run

      @conn
    end

    private

    # We have to "pump" the connection now and then -- check it to see if
    # any messages have come in and dispatch them.
    def conn_check
      STDERR.puts "conn_check"
      @conn.msg_check(duration: 0.05, wait_increment: 0.025)
    end

    public

    def app
      driver.app
    end

    def visit(path, **attributes)
      @visit_id += 1
      this_visit = @visit_id
      conn.navigate path
      @visit_html = nil

      STDERR.puts "EVAL_VALUE START"
      conn.eval_value("document.body.innerHTML") do |dom|
        STDERR.puts "EVAL_VALUE pkt: #{this_visit.inspect} current: #{@visit_id.inspect} val: #{dom.inspect}"
        if @visit_id == this_visit && dom
          @visit_html = dom
          @dom = Capybara::HTML(dom)
        end
      end
    end

    def dom
      html # make sure @visit_html is up to date
      @dom
    end

    def html
      start_t = Time.now
      while !@visit_html && (Time.now - start_t < DEFAULT_WAIT)
        conn_check
      end

      @visit_html
    end

    def refresh
      raise "Implement!"
    end

    def reset!
      STDERR.puts "reset!"
      if @conn
        @conn.kill
        @conn = nil
      end
    end


    def find(format, selector)
      if format == :css
        raise "Implement! CSSHandlers"
        dom.css(selector, Capybara::Webview::CSSHandlers.new)
      else
        dom.xpath(selector)
      end.map { |node| Capybara::Webview::Node.new(self, node) }
    end
  end
end