# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/safe"
require "sus/fixtures/console/captured_logger"
require "console"

describe "Async::Safe Logging" do
	include_context Sus::Fixtures::Console::CapturedLogger
	
	let(:test_class) do
		Class.new do
			def process
				"processed"
			end
		end
	end
	
	after do
		Async::Safe.disable! if Async::Safe.monitor
	end
	
	with "no logger (default)" do
		it "raises exceptions by default" do
			Async::Safe.enable!
			
			test_object = test_class.new
			test_object.process  # Establish ownership in main fiber
			
			expect do
				Fiber.new do
					test_object.process  # Should raise
				end.resume
			end.to raise_exception(Async::Safe::ViolationError)
		end
		
		it "raises exceptions when no logger provided" do
			Async::Safe.enable!(logger: nil)
			
			test_object = test_class.new
			test_object.process  # Establish ownership in main fiber
			
			expect do
				Fiber.new do
					test_object.process  # Should raise
				end.resume
			end.to raise_exception(Async::Safe::ViolationError)
		end
	end
	
	with "logger: Console" do
		it "logs violations instead of raising when logger provided" do
			Async::Safe.enable!(logger: Console)
			
			test_object = test_class.new
			test_object.process  # Establish ownership in main fiber
			
			# This should not raise an exception
			expect do
				Fiber.new do
					test_object.process  # Should log instead of raise
				end.resume
			end.not.to raise_exception
			
			# Check that a warning was logged with structured data
			last_log = console_capture.last
			expect(last_log).to have_keys(
				severity: be == :warn,
				subject: be_a(Async::Safe::Monitor), # The subject is the monitor instance
				message: be == "Async::Safe violation detected!", # The actual message
				klass: be_a(Class),
				method: be == :process,
				owner: be_a(Fiber),
				current: be_a(Fiber),
				backtrace: be_a(Array)
			)
			
			# Verify the fibers are different
			expect(last_log[:owner]).not.to be == last_log[:current]
		end
		
		it "continues execution after logging violations" do
			Async::Safe.enable!(logger: Console)
			
			test_object = test_class.new
			test_object.process  # Establish ownership in main fiber
			
			execution_completed = false
			
			Fiber.new do
				test_object.process  # Should log violation but not raise
				execution_completed = true  # This should execute
			end.resume
			
			expect(execution_completed).to be == true
			
			# Verify that a warning was logged with all expected structured data
			expect(console_capture.last).to have_keys(
				severity: be == :warn,
				subject: be_a(Async::Safe::Monitor), # The subject is the monitor instance
				message: be == "Async::Safe violation detected!", # The actual message
				klass: be_a(Class),
				method: be == :process,
				owner: be_a(Fiber),
				current: be_a(Fiber),
				backtrace: be_a(Array)
			)
		end
		
		it "includes useful backtrace information in logs" do
			Async::Safe.enable!(logger: Console)
			
			test_object = test_class.new
			test_object.process  # Establish ownership in main fiber
			
			Fiber.new do
				test_object.process  # Should log violation with backtrace
			end.resume
			
			last_log = console_capture.last
			backtrace = last_log[:backtrace]
			
			# Backtrace should be non-empty
			expect(backtrace.length).to be > 0
			
			# The backtrace entries should be Thread::Backtrace::Location objects
			first_entry = backtrace.first
			expect(first_entry).to be_a(Thread::Backtrace::Location)
			
			# The backtrace should contain entries - check if any reference the test files
			backtrace_strings = backtrace.map(&:to_s)
			has_test_reference = backtrace_strings.any? { |s| s.match?(/test.*logging\.rb/) }
			expect(has_test_reference).to be == true
		end
	end
end