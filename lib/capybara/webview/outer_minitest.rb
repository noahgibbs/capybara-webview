# frozen_string_literal: true

require "capybara"
require "minitest/test"
require "json"

module Capybara::Webview; end

# An OuterMinitest is meant to run an inner minitest, with just the one test body,
# in a separate process. This is needed for Webview testing on some platforms.
class Capybara::Webview::OuterMinitest < Minitest::Test
  include Capybara::DSL
  include Capybara::Minitest::Assertions
  def webview_capybara_test(&body)
    with_tempfile("wv_capy_test", "") do |_, temp_filename|
      pre_run_data = {
        assertions: self.assertions,
        failures: self.failures.dup,
      }

      child_pid = fork do
        # Pull the same data a Minitest reporter would
        # TODO: remember failures and assertions from last time and don't include them here
        test_klass = self.class
        run_data = {
          name: self.name,
          klass: test_klass.name,
          assertions: self.assertions,
          failures: self.failures.dup,
          time: self.time,
          metadata: self.metadata? ? self.metadata : nil,
          source_location: (self.method(self.name).source_location rescue ["unknown", -1])
        }

        File.write(temp_filename, JSON.dump(run_data))
        exit!
      end # end fork

      # Wait for test to complete
      Process.wait child_pid

      # Start from "couldn't make contact with the worker" failure until we make contact
      if File.exist?(temp_filename)
        begin
          test_data = JSON.parse temp_filename
          unless test_data.is_a?(Hash)
            assert false, "JSON data in incorrect format: #{test_data.inspect}"
            return
          end

          STDERR.puts "PRE-RUN DATA: #{pre_run_data.inspect}"
          STDERR.puts "TEST DATA: #{test_data.inspect}"

          # Minitest doesn't let us directly see the runner/reporter during a test,
          # so we can't do this directly. But we can make assertions, including
          # failures.
          (test_data[:assertions] - pre_run_data[:assertions]).times { assert true }
          # I'm not sure we can get more than one failing assertion here. But I think our
          # child-process test should have the same limitation.
          (test_data[:failures] - pre_run_data[:failures]).each { |f| assert false, f }
          # Don't think we can relay other information to local Minitest without
          # creating a new kind of runner or reporter. For now it'll be fine.
          # We *might* be able to pass the file and line through with some sort
          # of hideous eval chicanery.
        rescue
          assert false, "Couldn't parse JSON data: #{$!.message.inspect}"
          return
        end
      else
        assert false, "Couldn't receive data from Capybara Webview worker"
        return
      end
    end # end with_tempfile
  end

  private

  # Create a temporary file with the given prefix and contents.
  # Execute the block of code with it in place. Make sure
  # it gets cleaned up afterward.
  #
  # @param prefix [String] the prefix passed to Tempfile to identify this file on disk
  # @param contents [String] the file contents that should be written to Tempfile
  # @param dir [String] the directory to create the tempfile in
  # @yield The code to execute with the tempfile present
  # @yieldparam the path of the new tempfile
  def with_tempfile(prefix, contents, dir: Dir.tmpdir)
    t = Tempfile.new(prefix, dir)
    t.write(contents)
    t.flush # Make sure the contents are written out

    yield(t, t.path)
  ensure
    t.close
    t.unlink
  end
end
