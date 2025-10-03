# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "set"
require "weakref"

module Async
	module Safe
		# Raised when an object is accessed from a different fiber than the one that owns it.
		class ViolationError < StandardError
			def initialize(message = nil, target:, method:, owner:, current:)
				@target = target
				@method = method
				@owner = owner
				@current = current
				
				super(message || build_message)
			end
			
			attr_reader :object_class, :method, :owner, :current
			
			def as_json
				{
					object_class: @object_class,
					method: @method,
					owner: {
						name: @owner.inspect,
						backtrace: @owner.backtrace,
					},
					current: {
						name: @current.inspect,
						backtrace: @current.backtrace,
					},
				}
			end
			
			private def build_message
				"Thread safety violation detected! #{@target.inspect}##{@method} was accessed from #{@current.inspect} by #{@owner.inspect}."
			end
		end
		
		# The core monitoring implementation using TracePoint.
		#
		# This class tracks object ownership across fibers, detecting when an object
		# is accessed from a different fiber than the one that originally created or
		# accessed it.
		#
		# The monitor uses a TracePoint on `:call` events to track all method calls,
		# and maintains a registry of which fiber "owns" each object. Uses weak references
		# to avoid preventing garbage collection of tracked objects.
		class Monitor
			ASYNC_SAFE = true
			
			def initialize
				@owners = ObjectSpace::WeakMap.new
				@mutex = Thread::Mutex.new
				@trace_point = nil
			end
			
			attr :owners
			
			# Enable the monitor by activating the TracePoint.
			def enable!
				@trace_point ||= TracePoint.trace(:call, &method(:check_access))
			end
			
			# Disable the monitor by deactivating the TracePoint.
			def disable!
				if trace_point = @trace_point
					@trace_point = nil
					trace_point.disable
				end
			end
			
			# Reset all tracked ownership.
			def reset!
				@mutex.synchronize do
					@owners = ObjectSpace::WeakMap.new
				end
			end
			
			# Explicitly transfer ownership of objects to the current fiber.
			#
			# @parameter objects [Array(Object)] The objects to transfer.
			def transfer(*objects)
				@mutex.synchronize do
					current = Fiber.current
					
					objects.each do |object|
						@owners[object] = current
					end
				end
			end
			
			# Check if the current access is allowed or constitutes a violation.
			#
			# @parameter trace_point [TracePoint] The trace point containing access information.
			def check_access(trace_point)
				object = trace_point.self
				
				# Skip tracking class/module methods:
				return if object.is_a?(Class) || object.is_a?(Module)
				
				# Skip frozen objects:
				return if object.frozen?
				
				method = trace_point.method_id
				klass = trace_point.defined_class
				
				# Check the object's actual class:
				klass = object.class
				
				# Check if the class or method is marked as async-safe:
				if klass.async_safe?(method)
					return
				end
				
				# Track ownership:
				current = Fiber.current
				
				@mutex.synchronize do
					if owner = @owners[object]
						# Violation if accessed from different fiber:
						if owner != current
							raise ViolationError.new(
								target: object,
								method: method,
								owner: owner,
								current: current,
							)
						end
					else
						# First access - record owner:
						@owners[object] = current
					end
				end
			end
		end
	end
end

