# frozen_string_literal: true

require_relative "lib/capybara/webview/version"

Gem::Specification.new do |spec|
  spec.name = "capybara-webview"
  spec.version = Capybara::Webview::VERSION
  spec.authors = ["Noah Gibbs", "Scarpe Team"]
  spec.email = ["the.codefolio.guy@gmail.com"]

  spec.summary = "A Webview driver for Capybara."
  spec.description = "A Webview driver for the Capybara testing DSL, written in Ruby, for Javascript and HTML."
  spec.homepage = "https://github.com/noahgibbs/capybara-webview"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  #spec.bindir = "exe"
  #spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "webview_ruby", "~> 0.1.1"
  spec.add_dependency "capybara", ">= 3.39"
end
