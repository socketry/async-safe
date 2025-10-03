# Getting Started

This guide explains how to use `async-safe` to detect thread safety violations in your Ruby code.

## Installation

Add this line to your application's Gemfile:

~~~ ruby
gem 'async-safe'
~~~

And then execute:

~~~ bash
$ bundle install
~~~

Or install it yourself as:

~~~ bash
$ gem install async-safe
~~~

## Basic Monitoring

Enable monitoring in your test suite or development environment:

~~~ ruby
require 'async/safe'

# Enable monitoring
Async::Safe.enable!

# Your concurrent code here...
~~~

When a violation is detected, an `Async::Safe::ViolationError` will be raised immediately with details about the object, method, and execution contexts involved.

## Single-Owner Model (Default)

By default, all objects are assumed to follow a **single-owner model** - they should only be accessed from one fiber/thread at a time:

~~~ ruby
class MyBody
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

body = MyBody.new(["a", "b", "c"])
body.read  # OK - accessed from main fiber

Fiber.schedule do
  body.read  # 💥 Raises Async::Safe::ViolationError!
end
~~~

## Marking Async-Safe Classes

Mark entire classes as safe for concurrent access:

~~~ ruby
class MyQueue
  async_safe!
  
  def initialize
    @queue = Thread::Queue.new
  end
  
  def push(item)
    @queue.push(item)
  end
  
  def pop
    @queue.pop
  end
end

queue = MyQueue.new
queue.push("item")

Fiber.schedule do
  queue.push("another")  # ✅ OK - class is marked async-safe
end
~~~

Alternatively, you can manually set the constant:

~~~ ruby
class MyQueue
  ASYNC_SAFE = true
  
  # ... implementation
end
~~~

## Marking Async-Safe Methods

Mark specific methods as async-safe:

~~~ ruby
class MixedSafety
  include Async::Safe
  
  async_safe :safe_read
  
  def initialize(data)
    @data = data
    @count = 0
  end
  
  def safe_read
    @data  # Async-safe method
  end
  
  def increment
    @count += 1  # Not async-safe
  end
end

obj = MixedSafety.new("data")

Fiber.schedule do
  obj.safe_read  # ✅ OK - method is marked async-safe
  obj.increment  # 💥 Raises Async::Safe::ViolationError!
end
~~~

## Transferring Ownership

Explicitly transfer ownership between fibers:

~~~ ruby
request = create_request
process_in_main_fiber(request)

Fiber.schedule do
  Async::Safe.transfer(request)  # Transfer ownership
  process_in_worker_fiber(request)  # ✅ OK now
end
~~~

## Integration with Tests

Add to your test helper (e.g., `config/sus.rb` or `spec/spec_helper.rb`):

~~~ ruby
if ENV['SAFETY_CHECK']
  require 'async/safe'
  
  Async::Safe.enable!
end
~~~

Then run your tests with:

~~~ bash
$ SAFETY_CHECK=1 bundle exec sus
~~~

Any thread safety violations will cause your tests to fail immediately with a clear error message showing which object was accessed incorrectly and from which execution contexts.

## How It Works

1. **Default Assumption**: All objects follow a single-owner model (not thread-safe)
2. **TracePoint Monitoring**: Tracks which fiber/thread first accesses each object
3. **Violation Detection**: Raises an exception when a different fiber/thread accesses the same object
4. **Explicit Safety**: Objects/methods can be marked as thread-safe to allow concurrent access
5. **Zero Overhead**: Monitoring is only active when explicitly enabled

## Use Cases

- **Detecting concurrency bugs** in development and testing
- **Validating thread safety assumptions** in async/fiber-based code
- **Finding race conditions** before they cause production issues
- **Educational tool** for learning about thread safety in Ruby

## Performance

- **Zero overhead when disabled** - TracePoint is not activated
- **Minimal overhead when enabled** - suitable for development/test environments
- **Not recommended for production** - use only in development/testing

