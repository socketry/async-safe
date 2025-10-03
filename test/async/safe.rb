# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/safe"

MockTracePoint = Data.define(:self, :method_id, :defined_class, :path, :lineno)

describe Async::Safe do
	let(:body_class) do
		Class.new do
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
		# Reset monitoring state:
		subject.disable!
		subject.enable!
	end
	
	after do
		subject.disable!
	end
	
	it "can detect cross-fiber access" do
		body = body_class.new(["a", "b"])
		body.read  # Main fiber
		
		expect do
			Fiber.new do
				body.read  # Different fiber - should raise
			end.resume
		end.to raise_exception(Async::Safe::ViolationError)
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
	
	it "allows access after ownership transfer" do
		body = body_class.new(["a", "b"])
		body.read  # Main fiber owns it
		
		Fiber.new do
			Async::Safe.transfer(body)  # Transfer ownership
			body.read  # Should be OK now
		end.resume
	end
	
	it "detects violations on non-async-safe methods" do
		mixed_class = Class.new do
			include Async::Safe
			
			async_safe :safe_method
			
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
				instance.unsafe_method  # Should raise
			end.resume
		end.to raise_exception(Async::Safe::ViolationError) do |error|
			expect(error.method).to be == :unsafe_method
		end
	end
	
	with ".async_safe?" do
		it "returns false for non-async-safe classes" do
			regular_class = Class.new do
				include Async::Safe
				async_safe :some_method
				
				def some_method
					"data"
				end
				
				def other_method
					"other"
				end
			end
			
			# Class itself is not async-safe
			expect(regular_class.async_safe?).to be == false
			
			# Marked method is async-safe
			expect(regular_class.async_safe?(:some_method)).to be == true
			
			# Unmarked method is not async-safe
			expect(regular_class.async_safe?(:other_method)).to be == false
		end
	end
end

