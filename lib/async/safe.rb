# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "safe/version"
require_relative "safe/class"
require_relative "safe/monitor"
require_relative "safe/builtins"

# @namespace
module Async
	# Provides runtime thread safety monitoring for concurrent Ruby code.
	#
	# By default, all classes are assumed to be async-safe. Classes that follow a
	# **single-owner model** should be explicitly marked with `ASYNC_SAFE = false` to
	# enable tracking and violation detection.
	#
	# Enable monitoring in your test suite to catch concurrency bugs early.
	module Safe
		class << self
			# @attribute [Monitor] The global monitoring instance.
			attr_reader :monitor
			
			# Enable thread safety monitoring.
			#
			# This activates a TracePoint that tracks object access across fibers and threads.
			# There is no performance overhead when monitoring is disabled.
			def enable!
				@monitor ||= Monitor.new
				@monitor.enable!
			end
			
			# Disable thread safety monitoring.
			def disable!
				@monitor&.disable!
				@monitor = nil
			end
			
			# Explicitly transfer ownership of objects to the current fiber.
			#
			# This allows an object to be safely passed between fibers.
			#
			# @parameter objects [Array(Object)] The objects to transfer ownership of.
			#
			# ~~~ ruby
			# request = Request.new(...)
			# 
			# Fiber.schedule do
			# 	# Transfer ownership of the request to this fiber:
			# 	Async::Safe.transfer(request)
			# 	process(request)
			# end
			# ~~~
			def transfer(*objects)
				@monitor&.transfer(*objects)
			end
		end
	end
end

