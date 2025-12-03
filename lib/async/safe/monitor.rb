# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "violation_error"

module Async
	module Safe
		# Monitors for concurrent access to objects across fibers.
		#
		# This monitor detects when multiple fibers try to execute methods on the same
		# object simultaneously (actual data races). Sequential access across fibers is
		# allowed - objects can be passed between fibers freely.
		#
		# Uses TracePoint to track in-flight method calls and detect concurrent access.
		class Monitor
			ASYNC_SAFE = true
			
			# Initialize a new concurrency monitor.
			def initialize
				@guards = ObjectSpace::WeakMap.new  # Tracks {object => fiber} or {object => {guard => fiber}}
				@mutex = Thread::Mutex.new
				@trace_point = nil
			end
			
			attr :guards
			
			# Enable the monitor by activating the TracePoint.
			def enable!
				return if @trace_point
				
				@trace_point = TracePoint.new(:call, :return) do |tp|
					if tp.event == :call
						check_call(tp)
					else
						check_return(tp)
					end
				end
				
				@trace_point.enable
			end
			
			# Disable the monitor by deactivating the TracePoint.
			def disable!
				if trace_point = @trace_point
					@trace_point = nil
					trace_point.disable
				end
			end
			
			# Transfer has no effect in concurrency monitoring.
			#
			# Objects can move freely between fibers. This method exists for
			# backward compatibility but does nothing.
			#
			# @parameter objects [Array(Object)] The objects to transfer (ignored).
			def transfer(*objects)
				# No-op - objects move freely between fibers
			end
			
			# Check method call for concurrent access violations.
			#
			# @parameter trace_point [TracePoint] The trace point containing call information.
			private def check_call(trace_point)
				object = trace_point.self
				
				# Skip tracking class/module methods:
				return if object.is_a?(Module)
				
				# Skip frozen objects:
				return if object.frozen?
				
				method = trace_point.method_id
				
				# Check the object's actual class:
				klass = object.class
				
				# Check if the class or method is marked as async-safe:
				# Returns: true (skip), false (simple tracking), or Symbol (guard-based tracking)
				safe = klass.async_safe?(method)
				return if safe == true
				
				current = Fiber.current
				
				@mutex.synchronize do
					if safe == false
						# Simple tracking (single guard)
						if fiber = @guards[object]
							if fiber != current && !fiber.is_a?(Hash)
								# Concurrent access detected!
								raise ViolationError.new(
									"Concurrent access detected!",
									target: object,
									method: method,
									owner: fiber,
									current: current,
								)
							end
						else
							# Acquire the guard
							@guards[object] = current
						end
					else
						# Multi-guard tracking
						guard = safe
						
						# Get or create the guards hash for this object
						entry = @guards[object]
						if entry.nil? || !entry.is_a?(Hash)
							guards = @guards[object] = {}
						else
							guards = entry
						end
						
						# Check if another fiber currently holds this guard
						if fiber = guards[guard]
							if fiber != current
								# Concurrent access detected within the same guard!
								raise ViolationError.new(
									"Concurrent access detected (guard: #{guard})!",
									target: object,
									method: method,
									owner: fiber,
									current: current,
								)
							end
						else
							# Acquire this guard
							guards[guard] = current
						end
					end
				end
			end
			
			# Check method return to release guard.
			#
			# @parameter trace_point [TracePoint] The trace point containing return information.
			private def check_return(trace_point)
				object = trace_point.self
				
				# Skip tracking class/module methods:
				return if object.is_a?(Module)
				
				# Skip frozen objects:
				return if object.frozen?
				
				method = trace_point.method_id
				
				# Check the object's actual class:
				klass = object.class
				
				# Check if the class or method is marked as async-safe:
				safe = klass.async_safe?(method)
				return if safe == true
				
				current = Fiber.current
				
				@mutex.synchronize do
					entry = @guards[object]
					
					if safe == false
						# Simple tracking (single guard)
						# Release if this fiber holds it
						@guards.delete(object) if entry == current
					else
						# Multi-guard tracking
						guard = safe
						
						if entry.is_a?(Hash)
							entry.delete(guard) if entry[guard] == current
							# Clean up empty guards hash
							@guards.delete(object) if entry.empty?
						end
					end
				end
			end
		end
	end
end

