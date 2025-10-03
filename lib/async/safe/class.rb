# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

# Extend Class with a default async_safe? implementation
class Class
	# Check if this class or a specific method is async-safe.
	#
	# @parameter method [Symbol | Nil] The method name to check, or nil to check if the entire class is async-safe.
	# @returns [Boolean] Whether the class or method is async-safe.
	def async_safe?(method = nil)
		# Check if entire class is marked async-safe via constant:
		if const_defined?(:ASYNC_SAFE, false) && const_get(:ASYNC_SAFE)
			return true
		end
		
		false
	end
end

