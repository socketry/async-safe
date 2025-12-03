# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "safe/version"
require_relative "safe/class"
require_relative "safe/monitor"

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
			# This activates a TracePoint that detects concurrent access to objects across
			# fibers and threads. There is no performance overhead when monitoring is disabled.
			#
			# Objects can move freely between fibers - only actual concurrent access (data races)
			# is detected and reported.
			def enable!
				@monitor ||= Monitor.new
				@monitor.enable!
			end
			
			# Disable thread safety monitoring.
			def disable!
				@monitor&.disable!
				@monitor = nil
			end
			
			# Transfer has no effect in concurrency monitoring mode.
			#
			# Objects can move freely between fibers. This method is kept for
			# backward compatibility but does nothing.
			#
			# @parameter objects [Array(Object)] The objects to transfer (ignored).
			def transfer(*objects)
				# No-op - objects can move freely between fibers
			end
		end
	end
end

