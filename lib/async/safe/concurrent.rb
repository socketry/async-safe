# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Async
	module Safe
		# Mark a class as async-safe for concurrent access.
		#
		# When a class includes this module, all of its methods are considered safe
		# to call from multiple fibers simultaneously. This sets the `ASYNC_SAFE`
		# constant on the class.
		#
		# ## Usage
		#
		# ~~~ ruby
		# class MyQueue
		#   include Async::Safe::Concurrent
		#   
		#   def initialize
		#     @queue = Thread::Queue.new
		#   end
		#   
		#   def push(item)
		#     @queue.push(item)
		#   end
		# end
		# ~~~
		#
		# Objects of this class can now be safely accessed from multiple fibers
		# without triggering violations.
		module Concurrent
			def self.included(base)
				base.const_set(:ASYNC_SAFE, true) unless base.const_defined?(:ASYNC_SAFE)
			end
		end
	end
end

