# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/safe"

describe Async::Safe::ViolationError do
	it "can be serialized to JSON" do
		owner_fiber = Fiber.current
		current_fiber = Fiber.new{}.tap(&:resume)
		
		error = Async::Safe::ViolationError.new(
			target: "test_object",
			method: :test_method,
			owner: owner_fiber,
			current: current_fiber
		)
		
		json = error.as_json
		
		expect(json[:object_class]).to be == nil  # Not set
		expect(json[:method]).to be == :test_method
		expect(json[:owner]).to be_a(Hash)
		expect(json[:current]).to be_a(Hash)
	end
end
