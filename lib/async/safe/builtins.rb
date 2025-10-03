# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

# Mark Ruby's built-in thread-safe classes as async-safe
#
# Note: Immutable values (nil, true, false, integers, symbols, etc.) are already
# handled by the frozen? check in the monitor and don't need to be listed here.

# Thread synchronization primitives:
Thread::ASYNC_SAFE = true
Thread::Queue::ASYNC_SAFE = true
Thread::SizedQueue::ASYNC_SAFE = true
Thread::Mutex::ASYNC_SAFE = true
Thread::ConditionVariable::ASYNC_SAFE = true

# Fibers are async-safe:
Fiber::ASYNC_SAFE = true

# ObjectSpace::WeakMap is async-safe:
ObjectSpace::WeakMap::ASYNC_SAFE = true
