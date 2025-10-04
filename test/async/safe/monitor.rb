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
	
	let(:monitor) { Async::Safe::Monitor.new }
	
	with "#check_access" do
		it "records ownership on first access" do
			body = body_class.new(["a", "b"])
			trace_point = MockTracePoint.new(body, :read, body_class, "test.rb", 1)
			
			monitor.check_access(trace_point)
			
			expect(monitor.owners[body]).to be == Fiber.current
		end
		
		it "allows same fiber to access again" do
			body = body_class.new(["a", "b"])
			trace_point = MockTracePoint.new(body, :read, body_class, "test.rb", 1)
			
			monitor.check_access(trace_point)
			monitor.check_access(trace_point)
			
			expect(monitor.owners[body]).to be == Fiber.current
		end
		
		it "raises ViolationError when different fiber accesses object" do
			body = body_class.new(["a", "b"])
			trace_point = MockTracePoint.new(body, :read, body_class, "test.rb", 1)
			
			# First access from main fiber
			monitor.check_access(trace_point)
			
			# Second access from different fiber
			expect do
				Fiber.new do
					monitor.check_access(trace_point)
				end.resume
			end.to raise_exception(Async::Safe::ViolationError) do |error|
				expect(error.method).to be == :read
				expect(error.owner).to be_a(Fiber)
				expect(error.current).to be_a(Fiber)
				expect(error.owner).not.to be == error.current
			end
		end
		
		it "skips Class objects" do
			klass = Class.new
			trace_point = MockTracePoint.new(klass, :new, Class, "test.rb", 1)
			
			# Should return early and not track
			monitor.check_access(trace_point)
			
			expect(monitor.owners[klass]).to be == nil
		end
		
		it "skips Module objects" do
			mod = Module.new
			trace_point = MockTracePoint.new(mod, :included, Module, "test.rb", 1)
			
			# Should return early and not track
			monitor.check_access(trace_point)
			
			expect(monitor.owners[mod]).to be == nil
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
			monitor.check_access(trace_point)
			
			# Different fiber should be OK
			Fiber.new do
				monitor.check_access(trace_point)
			end.resume
			
			# Should not track ownership at all
			expect(monitor.owners[instance]).to be == nil
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
			monitor.check_access(trace_point)
			
			# Different fiber should be OK for async_safe method
			Fiber.new do
				monitor.check_access(trace_point)
			end.resume
			
			# Should not track ownership for async_safe methods
			expect(monitor.owners[instance]).to be == nil
		end
	end
end

