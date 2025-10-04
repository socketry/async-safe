# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/safe"
require "set"

describe "Async::Safe Builtins" do
	before do
		Async::Safe.enable!
	end
	
	after do
		Async::Safe.disable!
	end
	
	# Simple test to verify the transfer mechanism works
	it "can manually transfer object ownership" do
		test_class = Class.new do
			const_set(:ASYNC_SAFE, false)
			
			def process
				"processed"
			end
		end
		test_object = test_class.new
		
		# Use the object in main fiber to establish ownership
		test_object.process
		
		# Access from different fiber should raise error
		expect do
			Fiber.new do
				test_object.process
			end.resume
		end.to raise_exception(Async::Safe::ViolationError)
		
		# But after manual transfer, it should work
		Fiber.new do
			Async::Safe.transfer(test_object)
			test_object.process  # Should not raise
		end.resume
	end
	
	with "Thread::Queue" do
		it "is marked as async-safe" do
			expect(Thread::Queue.async_safe?).to be == true
		end
		
		it "allows concurrent access without transfer" do
			queue = Thread::Queue.new
			queue.push("item1")
			
			expect do
				Fiber.new do
					queue.push("item2")  # Should be OK - class is async-safe
				end.resume
			end.not.to raise_exception
		end
		
		it "transfers ownership of objects via pop" do
			queue = Thread::Queue.new
			
			# Create an object that will be monitored
			test_object = Class.new do
				def process
					"processed"
				end
			end.new
			
			# Use the object in main fiber to establish ownership
			test_object.process
			
			# Push it into the queue
			queue.push(test_object)
			
			# Pop from different fiber - should transfer ownership
			result = nil
			exception_raised = false
			
			begin
				Fiber.new do
					result = queue.pop
					# Should be able to use the object without violation after transfer
					result.process
				end.resume
			rescue Async::Safe::ViolationError
				exception_raised = true
			end
			
			# The transfer should work, so no exception should be raised
			expect(exception_raised).to be == false
			expect(result).to be == test_object
		end
		
		it "transfers ownership of objects via deq" do
			queue = Thread::Queue.new
			
			# Create an object that will be monitored
			test_object = Class.new do
				def process
					"processed"
				end
			end.new
			
			# Use the object in main fiber to establish ownership
			test_object.process
			
			# Push it into the queue
			queue.push(test_object)
			
			# Deq from different fiber - should transfer ownership
			result = nil
			exception_raised = false
			
			begin
				Fiber.new do
					result = queue.deq
					# Should be able to use the object without violation after transfer
					result.process
				end.resume
			rescue Async::Safe::ViolationError
				exception_raised = true
			end
			
			# The transfer should work, so no exception should be raised
			expect(exception_raised).to be == false
			expect(result).to be == test_object
		end
		
		it "transfers ownership of objects via shift" do
			queue = Thread::Queue.new
			
			# Create an object that will be monitored
			test_object = Class.new do
				def process
					"processed"
				end
			end.new
			
			# Use the object in main fiber to establish ownership
			test_object.process
			
			# Push it into the queue
			queue.push(test_object)
			
			# Shift from different fiber - should transfer ownership
			result = nil
			exception_raised = false
			
			begin
				Fiber.new do
					result = queue.shift
					# Should be able to use the object without violation after transfer
					result.process
				end.resume
			rescue Async::Safe::ViolationError
				exception_raised = true
			end
			
			# The transfer should work, so no exception should be raised
			expect(exception_raised).to be == false
			expect(result).to be == test_object
		end
		
		it "handles multiple objects in queue correctly" do
			queue = Thread::Queue.new
			
			# Create multiple objects with different owners
			object1 = Class.new do
				def id; 1; end
			end.new
			
			object2 = Class.new do
				def id; 2; end
			end.new
			
			# Establish ownership in main fiber
			object1.id
			object2.id
			
			# Push both objects
			queue.push(object1)
			queue.push(object2)
			
			# Pop from different fiber
			results = []
			ids = []
			exception_raised = false
			
			begin
				Fiber.new do
					results << queue.pop  # Should get object2 (LIFO for Queue)
					results << queue.pop  # Should get object1
					
					# Should be able to use both objects after transfer
					ids << results[0].id
					ids << results[1].id
				end.resume
			rescue Async::Safe::ViolationError
				exception_raised = true
			end
			
			expect(exception_raised).to be == false
			# Queue order can vary, but both objects should be retrievable
			expect(ids.sort).to be == [1, 2]
		end
	end
	
	with "Thread::SizedQueue" do
		it "is marked as async-safe" do
			expect(Thread::SizedQueue.async_safe?).to be == true
		end
		
		it "allows concurrent access without transfer" do
			queue = Thread::SizedQueue.new(2)
			queue.push("item1")
			
			expect do
				Fiber.new do
					queue.push("item2")  # Should be OK - class is async-safe
				end.resume
			end.not.to raise_exception
		end
		
		it "transfers ownership of objects via pop" do
			queue = Thread::SizedQueue.new(2)
			
			# Create an object that will be monitored
			test_object = Class.new do
				def process
					"processed"
				end
			end.new
			
			# Use the object in main fiber to establish ownership
			test_object.process
			
			# Push it into the queue
			queue.push(test_object)
			
			# Pop from different fiber - should transfer ownership
			result = nil
			exception_raised = false
			
			begin
				Fiber.new do
					result = queue.pop
					# Should be able to use the object without violation after transfer
					result.process
				end.resume
			rescue Async::Safe::ViolationError
				exception_raised = true
			end
			
			# The transfer should work, so no exception should be raised
			expect(exception_raised).to be == false
			expect(result).to be == test_object
		end
		
		it "transfers ownership with size limits" do
			queue = Thread::SizedQueue.new(1)  # Only allow 1 item
			
			# Create an object
			test_object = Class.new do
				def process
					"processed"
				end
			end.new
			
			# Establish ownership
			test_object.process
			
			# Fill the queue
			queue.push(test_object)
			
			# Pop from different fiber to test transfer
			result = nil
			exception_raised = false
			
			begin
				Fiber.new do
					result = queue.pop
					# Should be able to use the object without violation after transfer
					result.process
				end.resume
			rescue Async::Safe::ViolationError
				exception_raised = true
			end
			
			# The transfer should work, so no exception should be raised
			expect(exception_raised).to be == false
			expect(result).to be == test_object
		end
	end
	
	with "Immutable objects" do
		it "doesn't track ownership for frozen objects" do
			queue = Thread::Queue.new
			
			# Frozen objects should not be tracked
			frozen_string = "test".freeze
			frozen_array = [1, 2, 3].freeze
			
			queue.push(frozen_string)
			queue.push(frozen_array)
			
			# Should be able to access from different fiber without issue
			retrieved_string = nil
			retrieved_array = nil
			exception_raised = false
			
			begin
				Fiber.new do
					retrieved_string = queue.pop
					retrieved_array = queue.pop
				end.resume
			rescue Async::Safe::ViolationError
				exception_raised = true
			end
			
			# These shouldn't cause violations since they're frozen
			expect(exception_raised).to be == false
			expect(retrieved_string).to be == "test"
			expect(retrieved_array).to be == [1, 2, 3]
		end
		
		it "doesn't track basic immutable values" do
			queue = Thread::Queue.new
			
			# Basic immutable values
			queue.push(nil)
			queue.push(true)
			queue.push(false)
			queue.push(42)
			queue.push(:symbol)
			
			values = []
			exception_raised = false
			
			begin
				Fiber.new do
					5.times { values << queue.pop }
				end.resume
			rescue Async::Safe::ViolationError
				exception_raised = true
			end
			
			expect(exception_raised).to be == false
			# Check that all expected values are present (order may vary due to queue LIFO behavior)
			expect(values.length).to be == 5
			# Convert to sets for comparison since order doesn't matter
			actual_set = Set.new(values)
			expected_set = Set.new([nil, true, false, 42, :symbol])
			expect(actual_set).to be == expected_set
		end
	end
end