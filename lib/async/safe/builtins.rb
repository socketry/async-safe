# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

# Mark Ruby's built-in thread-safe classes as async-safe
#
# Note: Immutable values (nil, true, false, integers, symbols, etc.) are already
# handled by the frozen? check in the monitor and don't need to be listed here.

# Arrays contain references to other objects that may need transfer:
class Array
	ASYNC_SAFE = false
	
	def self.async_safe_traverse(instance, &block)
		instance.each(&block)
	end
end

# Hashes contain keys and values that may need transfer:
class Hash
	ASYNC_SAFE = false
	
	def self.async_safe_traverse(instance, &block)
		instance.each_key(&block)
		instance.each_value(&block)
	end
end

# Sets contain elements that may need transfer:
class Set
	ASYNC_SAFE = false
	
	def self.async_safe_traverse(instance, &block)
		instance.each(&block)
	end
end

module Async
	module Safe
		# Automatically transfers ownership of objects when they are removed from a Thread::Queue.
		#
		# When included in Thread::Queue or Thread::SizedQueue, this module wraps pop/deq/shift
		# methods to automatically transfer ownership of the dequeued object to the fiber that
		# dequeues it.
		module TransferableThreadQueue
			# Pop an object from the queue and transfer ownership to the current fiber.
			#
			# @parameter arguments [Array] Arguments passed to the original pop method.
			# @returns [Object] The dequeued object with transferred ownership.
			def pop(...)
				object = super(...)
				Async::Safe.transfer(object)
				object
			end
			
			# Dequeue an object from the queue and transfer ownership to the current fiber.
			#
			# Alias for {#pop}.
			#
			# @parameter arguments [Array] Arguments passed to the original deq method.
			# @returns [Object] The dequeued object with transferred ownership.
			def deq(...)
				object = super(...)
				Async::Safe.transfer(object)
				object
			end
			
			# Shift an object from the queue and transfer ownership to the current fiber.
			#
			# Alias for {#pop}.
			#
			# @parameter arguments [Array] Arguments passed to the original shift method.
			# @returns [Object] The dequeued object with transferred ownership.
			def shift(...)
				object = super(...)
				Async::Safe.transfer(object)
				object
			end
		end
	end
end

Thread::Queue.prepend(Async::Safe::TransferableThreadQueue)
Thread::SizedQueue.prepend(Async::Safe::TransferableThreadQueue)
