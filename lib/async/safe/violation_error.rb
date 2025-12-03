# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Async
	module Safe
		# Raised when an object is accessed from a different fiber than the one that owns it.
		class ViolationError < StandardError
			# Initialize a new violation error.
			#
			# @parameter message [String | Nil] Optional custom message.
			# @parameter target [Object] The object that was accessed.
			# @parameter method [Symbol] The method that was called.
			# @parameter owner [Fiber] The fiber that owns the object.
			# @parameter current [Fiber] The fiber that attempted to access the object.
			def initialize(message = nil, target:, method:, owner:, current:)
				@target = target
				@method = method
				@owner = owner
				@current = current
				
				super(message || build_message)
			end
			
			attr_reader :object_class, :method, :owner, :current
			
			# Convert the violation error to a JSON-serializable hash.
			#
			# @returns [Hash] A hash representation of the violation.
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
				"Thread safety violation detected!\n\tObject: #{@target.inspect}##{@method}\n\tOwner: #{@owner.inspect}\n\tAccessed by: #{@current.inspect}"
			end
		end
	end
end

