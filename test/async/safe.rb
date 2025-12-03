# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/safe"
require "async"

MockTracePoint = Data.define(:self, :method_id, :defined_class, :path, :lineno)

describe Async::Safe do
	let(:body_class) do
		Class.new do
			async_safe!(false)
			
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
	end
	
	before do
		subject.enable!
	end
	
	after do
		subject.disable!
	end
	
	it "allows sequential cross-fiber access" do
		body = body_class.new(["a", "b"])
		body.read  # Main fiber
		
		expect do
			Fiber.new do
				body.read  # Different fiber - OK, sequential access
			end.resume
		end.not.to raise_exception
	end
	
	it "allows access from same fiber" do
		body = body_class.new(["a", "b"])
		body.read
		
		expect do
			body.read  # Same fiber - should be OK
		end.not.to raise_exception
	end
	
	it "allows concurrent access to async-safe classes" do
		queue_class = Class.new do
			async_safe!
			
			def push(item)
				@items ||= []
				@items << item
			end
		end
		
		queue = queue_class.new
		queue.push("a")
		
		expect do
			Fiber.new do
				queue.push("b")  # Should be OK
			end.resume
		end.not.to raise_exception
	end
	
	
	it "allows access after method completes" do
		body = body_class.new(["a", "b"])
		body.read  # Main fiber
		
		Fiber.new do
			# No transfer needed - sequential access is allowed
			body.read  # Should be OK
		end.resume
	end
	
	it "allows sequential access to non-async-safe methods" do
		mixed_class = Class.new do
			async_safe!(safe_method: true)
			
			def safe_method
				"safe"
			end
			
			def unsafe_method
				"unsafe"
			end
		end
		
		instance = mixed_class.new
		instance.safe_method
		instance.unsafe_method
		
		expect do
			Fiber.new do
				instance.safe_method  # Should be OK
				instance.unsafe_method  # Should be OK (sequential)
			end.resume
		end.not.to raise_exception
	end
	
	with ".async_safe?" do
		it "returns correct values for hash-based configuration" do
			regular_class = Class.new do
				async_safe!(some_method: true, other_method: false)
			end
			
			# Marked method is async-safe
			expect(regular_class.async_safe?(:some_method)).to be == true
			
			# Explicitly false method
			expect(regular_class.async_safe?(:other_method)).to be == false
			
			# Method not in hash defaults to false (tracked)
			expect(regular_class.async_safe?(:unknown_method)).to be == false
		end
		
		it "returns correct values for array-based configuration" do
			regular_class = Class.new do
				async_safe!([:read, :inspect])
			end
			
			# Methods in array are async-safe
			expect(regular_class.async_safe?(:read)).to be == true
			expect(regular_class.async_safe?(:inspect)).to be == true
			
			# Methods not in array default to false (tracked)
			expect(regular_class.async_safe?(:write)).to be == false
		end
		
		it "defaults to true when no ASYNC_SAFE constant" do
			regular_class = Class.new
			
			# No constant means async-safe by default
			expect(regular_class.async_safe?).to be == true
			expect(regular_class.async_safe?(:any_method)).to be == true
		end
		
		it "returns false for hash without method argument" do
			regular_class = Class.new do
				async_safe!(read: true, write: false)
			end
			
			# Hash config without method returns false
			expect(regular_class.async_safe?).to be == false
		end
		
		it "returns false for array without method argument" do
			regular_class = Class.new do
				async_safe!([:read, :write])
			end
			
			# Array config without method returns false
			expect(regular_class.async_safe?).to be == false
		end
	end
	
	
	with "concurrency detection" do
		let(:counter_class) do
			Class.new do
				async_safe!(false)
				
				def initialize
					@count = 0
				end
				
				def increment
					@count += 1
				end
				
				def value
					@count
				end
			end
		end
		
		it "allows sequential cross-fiber access" do
			counter = counter_class.new
			counter.increment  # Main fiber
			
			expect do
				Fiber.new do
					# No transfer needed - sequential access is allowed
					counter.increment
				end.resume
			end.not.to raise_exception
		end
		
		it "detects actual concurrent access" do
			# Create a class with a method that actually takes time
			slow_class = Class.new do
				async_safe!(false)
				
				def initialize
					@value = 0
				end
				
				def slow_increment
					# Simulate work that takes time
					@value += 1
					sleep 0.1  # Actual work happening inside the method
					@value
				end
				
				def fast_read
					@value
				end
			end
			
			object = slow_class.new
			
			expect do
				Sync do |task|
					# Start a long-running method:
					task.async do
						object.slow_increment  # Takes 0.1 seconds.
					end
					
					# Try to access while first method is still running:
					task.async do
						sleep 0.05  # Wait for first task to start.
						object.fast_read  # Concurrent access!
					end.wait
				end
			end.to raise_exception(Async::Safe::ViolationError)
		end
		
		it "allows access after previous fiber completes" do
			counter = counter_class.new
			counter.increment  # Main fiber: count = 1
			
			Fiber.new do
				counter.increment  # Auto-transfer: count = 2
				counter.value
			end.resume
			
			# Main fiber accesses again after other fiber is done
			expect do
				counter.value  # Should auto-transfer back, no concurrent access
			end.not.to raise_exception
		end
	end
end
