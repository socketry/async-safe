#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "../lib/async/safe"

# Enable monitoring
Async::Safe.enable!

puts "=== Basic Thread Safety Examples ===\n\n"

# Example 1: Sequential access across fibers
puts "1. Single-owner object accessed from multiple fibers:"

class MyBody
	ASYNC_SAFE = false  # Enable tracking
	
	def initialize(chunks)
		@chunks = chunks
		@index = 0
	end
	
	def read
		chunk = @chunks[@index]
		@index += 1
		chunk
	end
end

body = MyBody.new(["chunk1", "chunk2", "chunk3"])
puts "Main fiber: #{body.read}"

Fiber.new do
	puts "Other fiber: #{body.read}"  # ✅ OK - sequential access
end.resume

# Example 2: Async-safe class
puts "\n2. Async-safe class (no violation):"

class SafeQueue
	async_safe!
	
	def initialize
		@items = []
	end
	
	def push(item)
		@items << item
		puts "Pushed: #{item}"
	end
end

queue = SafeQueue.new
queue.push("item1")

Fiber.new do
	queue.push("item2")  # OK - class is thread-safe
end.resume

# Example 3: Collections
puts "\n3. Collections can be used across fibers:"

items = ["a", "b", "c"]
items.each{|x| puts "Main: #{x}"}

Fiber.new do
	puts "Other fiber can access: #{items.first}"
end.resume

puts "\n✅ Example completed"

