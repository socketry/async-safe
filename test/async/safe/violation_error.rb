# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/safe"

describe Async::Safe::ViolationError do
	let(:owner_fiber) {Fiber.current}
	let(:current_fiber) {Fiber.new{}.tap(&:resume)}
	
	let(:error) do
		Async::Safe::ViolationError.new(
			target: "test_object",
			method: :test_method,
			owner: owner_fiber,
			current: current_fiber
		)
	end
	
	it "exposes object_class as the class of the target" do
		expect(error.object_class).to be == String
	end
	
	it "exposes the target object" do
		expect(error.target).to be == "test_object"
	end
	
	it "exposes the method name" do
		expect(error.method).to be == :test_method
	end
	
	it "exposes owner and current fibers" do
		expect(error.owner).to be == owner_fiber
		expect(error.current).to be == current_fiber
	end
	
	it "serializes object_class correctly in as_json" do
		json = error.as_json
		
		expect(json[:object_class]).to be == String
		expect(json[:method]).to be == :test_method
		expect(json[:owner]).to be_a(Hash)
		expect(json[:current]).to be_a(Hash)
	end
end
