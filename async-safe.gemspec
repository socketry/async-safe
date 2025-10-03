# frozen_string_literal: true

require_relative "lib/async/safe/version"

Gem::Specification.new do |spec|
	spec.name = "async-safe"
	spec.version = Async::Safe::VERSION
	
	spec.summary = "Runtime thread safety monitoring for concurrent Ruby code."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.homepage = "https://github.com/socketry/async-safe"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/async-safe/",
		"homepage_uri" => "https://github.com/socketry/async-safe",
		"source_code_uri" => "https://github.com/socketry/async-safe",
	}
	
	spec.files = Dir["{lib}/**/*", "*.md", base: __dir__]
	
	spec.required_ruby_version = ">= 3.2"
end
