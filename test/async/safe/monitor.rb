# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/safe"

MockTracePoint = Data.define(:self, :method_id, :defined_class, :path, :lineno)

describe Async::Safe::Monitor do
	let(:body_class) do
		Class.new do
			const_set(:ASYNC_SAFE, false)
			
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
	
	let(:monitor) {subject.new}
	
	it "records guard on first access" do
		body = body_class.new(["a", "b"])
		trace_point = MockTracePoint.new(body, :read, body_class, "test.rb", 1)
		
		monitor.send(:check_call, trace_point)
		
		# Simple tracking (no guard symbols) - just stores the fiber
		expect(monitor.guards[body]).to be == Fiber.current
	end
	
	it "allows same fiber to access again" do
		body = body_class.new(["a", "b"])
		trace_point = MockTracePoint.new(body, :read, body_class, "test.rb", 1)
		
		monitor.send(:check_call, trace_point)
		monitor.send(:check_call, trace_point)
		
		# Simple tracking (no guard symbols) - just stores the fiber
		expect(monitor.guards[body]).to be == Fiber.current
	end
	
	it "allows different fiber to access after method completes" do
		body = body_class.new(["a", "b"])
		trace_point = MockTracePoint.new(body, :read, body_class, "test.rb", 1)
		
		# First access from main fiber
		monitor.send(:check_call, trace_point)
		expect(monitor.guards[body]).to be == Fiber.current
		
		# Complete the call (release guard)
		monitor.send(:check_return, trace_point)
		
		# Should be cleared now
		expect(monitor.guards[body]).to be == nil
		
		# Second access from different fiber - should work (guard released)
		Fiber.new do
			monitor.send(:check_call, trace_point)
			expect(monitor.guards[body]).to be == Fiber.current
			monitor.send(:check_return, trace_point)
		end.resume
	end
	
	it "skips Class objects" do
		klass = Class.new
		trace_point = MockTracePoint.new(klass, :new, Class, "test.rb", 1)
		
		# Should return early and not track
		monitor.send(:check_call, trace_point)
		
		expect(monitor.guards[klass]).to be == nil
	end
	
	it "skips Module objects" do
		mod = Module.new
		trace_point = MockTracePoint.new(mod, :included, Module, "test.rb", 1)
		
		# Should return early and not track
		monitor.send(:check_call, trace_point)
		
		expect(monitor.guards[mod]).to be == nil
	end
	
	it "allows access to objects with ASYNC_SAFE constant" do
		safe_class = Class.new do
			def read
				"data"
			end
		end
		safe_class.async_safe!
		
		instance = safe_class.new
		trace_point = MockTracePoint.new(instance, :read, safe_class, "test.rb", 1)
		
		# Verify the constant is set
		expect(safe_class.const_get(:ASYNC_SAFE)).to be == true
		
		# First access
		monitor.send(:check_call, trace_point)
		
		# Different fiber should be OK
		Fiber.new do
			monitor.send(:check_call, trace_point)
		end.resume
		
		# Should not track at all
		expect(monitor.guards[instance]).to be == nil
	end
	
	it "allows access to methods marked async_safe via hash" do
		mixed_class = Class.new do
			const_set(:ASYNC_SAFE, {safe_read: true, unsafe_write: false}.freeze)
			
			def safe_read
				"data"
			end
			
			def unsafe_write
				"data"
			end
		end
		
		instance = mixed_class.new
		trace_point = MockTracePoint.new(instance, :safe_read, mixed_class, "test.rb", 1)
		
		# First access
		monitor.send(:check_call, trace_point)
		
		# Different fiber should be OK for async_safe method
		Fiber.new do
			monitor.send(:check_call, trace_point)
		end.resume
		
		# Should not track for async_safe methods
		expect(monitor.guards[instance]).to be == nil
	end
	
	with "guard-based concurrency control" do
		it "allows concurrent access to different guards" do
			stream_class = Class.new do
				def self.async_safe?(method)
					case method
					when :read then :readable
					when :write then :writable
					else false
					end
				end
				
				const_set(:ASYNC_SAFE, false)
				
				def read
					"reading"
				end
				
				def write
					"writing"
				end
			end
			
			stream = stream_class.new
			read_tp = MockTracePoint.new(stream, :read, stream_class, "test.rb", 1)
			write_tp = MockTracePoint.new(stream, :write, stream_class, "test.rb", 2)
			
			main_fiber = Fiber.current
			
			# Start a read operation (guard: :readable)
			monitor.send(:check_call, read_tp)
			expect(monitor.guards[stream]).to be == {readable: main_fiber}
			
			# Concurrent write should work (guard: :writable)
			write_fiber = Fiber.new do
				monitor.send(:check_call, write_tp)
				# Both guards should be held, different fibers
				expect(monitor.guards[stream]).to be == {readable: main_fiber, writable: Fiber.current}
			end
			write_fiber.resume
		end
		
		it "detects concurrent access within the same guard" do
			stream_class = Class.new do
				def self.async_safe?(method)
					method == :read ? :readable : false
				end
				
				const_set(:ASYNC_SAFE, false)
				
				def read
					"reading"
				end
			end
			
			stream = stream_class.new
			read_tp = MockTracePoint.new(stream, :read, stream_class, "test.rb", 1)
			
			# Start a read operation (guard: :readable)
			monitor.send(:check_call, read_tp)
			
			# Concurrent read should fail (same guard: :readable)
			expect do
				Fiber.new do
					monitor.send(:check_call, read_tp)
				end.resume
			end.to raise_exception(Async::Safe::ViolationError) do |error|
				expect(error.message).to include("guard: readable")
			end
		end
	end
end

