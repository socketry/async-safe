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
	# By default, all objects follow a **single-owner model** - they should only be accessed
	# from one fiber/thread at a time. Objects or methods can be explicitly marked as
	# async-safe to allow concurrent access.
	module Safe
		# Include this module to mark specific methods as async-safe
		def self.included(base)
			base.extend(ClassMethods)
		end
		
		# Class methods for marking async-safe methods
		module ClassMethods
			# Mark one or more methods as async-safe.
			#
			# @parameter method_names [Array(Symbol)] The methods to mark as async-safe.
			def async_safe(*method_names)
				@async_safe_methods ||= Set.new
				@async_safe_methods.merge(method_names)
			end
			
			# Check if a method is async-safe.
			#
			# Overrides the default implementation from `Class` to also check method-level safety.
			#
			# @parameter method [Symbol | Nil] The method name to check, or nil to check if the entire class is async-safe.
			# @returns [Boolean] Whether the method or class is async-safe.
			def async_safe?(method = nil)
				# Check if entire class is marked async-safe:
				return true if super
				
				# Check if specific method is marked async-safe:
				if method
					return @async_safe_methods&.include?(method)
				end
				
				# Default to false if no method is specified and the class is not async safe:
				return false
			end
		end
		
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

