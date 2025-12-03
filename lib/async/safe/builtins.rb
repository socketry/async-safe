# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

# Mark Ruby's built-in thread-safe classes as async-safe
#
# Note: Immutable values (nil, true, false, integers, symbols, etc.) are already
# handled by the frozen? check in the monitor and don't need to be listed here.

# Mark collections as not async-safe since they're typically mutable.
# Objects can still move between fibers, but concurrent access is detected.
class Array
	ASYNC_SAFE = false
end

class Hash
	ASYNC_SAFE = false
end

class Set
	ASYNC_SAFE = false
end
