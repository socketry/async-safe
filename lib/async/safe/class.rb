# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

# Extend Class with a default async_safe? implementation
class Class
	# Check if this class or a specific method is async-safe.
	#
	# The `ASYNC_SAFE` constant can be:
	# - `true` - entire class is async-safe.
	# - `false` - entire class is NOT async-safe (single-owner).
	# - `{method_name: true/false}` - per-method configuration.
	# - `[method_name1, method_name2]` - per-method configuration.
	#
	# @parameter method [Symbol | Nil] The method name to check, or nil to check if the entire class is async-safe.
	# @returns [Boolean] Whether the class or method is async-safe. Defaults to true if not specified.
	def async_safe?(method = nil)
		if const_defined?(:ASYNC_SAFE)
			async_safe = const_get(:ASYNC_SAFE)
			
			case async_safe
			when Hash
				if method
					async_safe = async_safe.fetch(method, false)
				else
					# In general, some methods may not be safe:
					async_safe = false
				end
			when Array
				if method
					async_safe = async_safe.include?(method)
				else
					# In general, some methods may not be safe:
					async_safe = false
				end
			end
			
			return async_safe
		end
		
		# Default to true:
		return true
	end
	
	# Mark the class as async-safe or not.
	#
	# @parameter value [Boolean | Hash | Array] Configuration for async-safety.
	# @returns [Boolean | Hash | Array] The configured value.
	def async_safe!(value = true)
		self.const_set(:ASYNC_SAFE, value)
	end
	
	# Define how to traverse this object's children during ownership transfer.
	#
	# This method is called by `Async::Safe.transfer` to recursively transfer
	# ownership of contained objects. By default, only the object itself is transferred.
	# Define this method to enable deep transfer for collection-like classes.
	#
	# @parameter instance [Object] The instance to traverse.
	# @parameter block [Proc] Block to call for each child object that should be transferred.
	#
	# ~~~ ruby
	# class MyContainer
	#   async_safe!(false)
	#   attr_reader :children
	#   
	#   def self.async_safe_traverse(instance, &block)
	#     instance.children.each(&block)
	#   end
	# end
	# ~~~
	def async_safe_traverse(instance, &block)
		# Default: no traversal (shallow transfer only)
	end
end
