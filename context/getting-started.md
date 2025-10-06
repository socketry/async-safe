# Getting Started

This guide explains how to use `async-safe` to detect thread safety violations in your Ruby code.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add async-safe
~~~

## Usage

Enable monitoring in your test suite or development environment:

~~~ ruby
require 'async/safe'

# Enable monitoring
Async::Safe.enable!

# Your concurrent code here...
~~~

When a violation is detected, an `Async::Safe::ViolationError` will be raised immediately with details about the object, method, and execution contexts involved.

### Single-Owner Model

By default, all classes are assumed to be async-safe. To enable tracking for specific classes, mark them with `ASYNC_SAFE = false`:

~~~ ruby
class MyBody
  ASYNC_SAFE = false  # Enable tracking for this class
  
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

### Marking Async-Safe Classes

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

Or use a hash for per-method configuration:

~~~ ruby
class MixedClass
  ASYNC_SAFE = {
    read: true,    # This method is async-safe
    write: false   # This method is NOT async-safe
  }.freeze
  
  # ... implementation
end
~~~

### Marking Methods with Hash

Use a hash to specify which methods are async-safe:

~~~ ruby
class MixedSafety
  ASYNC_SAFE = {
    safe_read: true,   # This method is async-safe
    increment: false   # This method is NOT async-safe
  }.freeze
  
  def initialize(data)
    @data = data
    @count = 0
  end
  
  def safe_read
    @data  # Async-safe method
  end
  
  def increment
    @count += 1  # Not async-safe - will be tracked
  end
end

obj = MixedSafety.new("data")

Fiber.schedule do
  obj.safe_read  # ✅ OK - method is marked async-safe
  obj.increment  # 💥 Raises Async::Safe::ViolationError!
end
~~~

Or use an array to list async-safe methods:

~~~ ruby
class MyClass
  ASYNC_SAFE = [:read, :inspect].freeze
  
  # read and inspect are async-safe
  # all other methods will be tracked
end
~~~

### Transferring Ownership

Explicitly transfer ownership between fibers:

~~~ ruby
request = create_request
process_in_main_fiber(request)

Fiber.schedule do
  Async::Safe.transfer(request)  # Transfer ownership
  process_in_worker_fiber(request)  # ✅ OK now
end
~~~

### Deep Transfer with Traversal

By default, `transfer` only transfers the object itself (shallow). For collections like `Array`, `Hash`, and `Set`, the gem automatically traverses and transfers contained objects:

~~~ ruby
bodies = [Body.new, Body.new]

Async::Safe.transfer(bodies)  # Transfers array AND all bodies inside
~~~

Custom classes can define traversal behavior using `async_safe_traverse`:

~~~ ruby
class Request
  async_safe!(false)
  attr_accessor :body, :headers
  
  def self.async_safe_traverse(instance, &block)
    yield instance.body
    yield instance.headers
  end
end

request = Request.new
request.body = Body.new
request.headers = Headers.new

Async::Safe.transfer(request)  # Transfers request, body, AND headers.
~~~

**Note:** Shareable objects (`async_safe? -> true`) are never traversed or transferred, as they can be safely shared across fibers.

## Integration with Tests

Add to your test helper (e.g., `config/sus.rb` or `spec/spec_helper.rb`):

~~~ ruby
require 'async/safe'

Async::Safe.enable!
~~~

Then run your tests normally:

~~~ bash
$ bundle exec sus
~~~

Any thread safety violations will cause your tests to fail immediately with a clear error message showing which object was accessed incorrectly and from which fibers.

## Determining Async Safety

When deciding whether to mark a class or method with `ASYNC_SAFE = false`, consider these factors:

### Async-Safe Patterns

**Immutable objects:**
~~~ ruby
class ImmutableUser
  def initialize(name, email)
    @name = name.freeze
    @email = email.freeze
    freeze  # Entire object is frozen
  end
  
  attr_reader :name, :email
end
~~~

**Pure functions (no state modification):**
~~~ ruby
class Calculator
  def add(a, b)
    a + b  # No instance state, pure computation
  end
end
~~~

**Thread-safe synchronization:**
~~~ ruby
class SafeQueue
  ASYNC_SAFE = true  # Explicitly marked
  
  def initialize
    @queue = Thread::Queue.new  # Thread-safe internally
  end
  
  def push(item)
    @queue.push(item)  # Delegates to thread-safe queue
  end
end
~~~

### Unsafe (Single-Owner) Patterns

**Mutable instance state:**
~~~ ruby
class Counter
  ASYNC_SAFE = false  # Enable tracking
  
  def initialize
    @count = 0
  end
  
  def increment
    @count += 1  # Reads and writes @count (race condition!)
  end
end
~~~

**Stateful iteration:**
~~~ ruby
class Reader
  ASYNC_SAFE = false  # Enable tracking
  
  def initialize(data)
    @data = data
    @index = 0
  end
  
  def read
    value = @data[@index]
    @index += 1  # Mutates state
    value
  end
end
~~~

**Lazy initialization:**
~~~ ruby
class DataLoader
  ASYNC_SAFE = false  # Enable tracking
  
  def data
    @data ||= load_data  # Not atomic! (race condition)
  end
end
~~~

### Mixed Safety

Use hash or array configuration for classes with both safe and unsafe methods:

~~~ ruby
class MixedClass
  ASYNC_SAFE = {
    read_config: true,   # Safe: only reads frozen data
    update_state: false  # Unsafe: modifies mutable state
  }.freeze
  
  def initialize
    @config = {setting: "value"}.freeze
    @state = {count: 0}
  end
  
  def read_config
    @config[:setting]  # Safe: frozen hash
  end
  
  def update_state
    @state[:count] += 1  # Unsafe: mutates state
  end
end
~~~

### Quick Checklist

Mark a method as unsafe (`ASYNC_SAFE = false`) if it:
- ❌ Modifies instance variables.
- ❌ Uses `||=` for lazy initialization.
- ❌ Iterates with mutable state (like `@index`).
- ❌ Reads then writes shared state.
- ❌ Accesses mutable collections without synchronization.

A method is likely safe if it:
- ✅ Only reads from frozen/immutable data.
- ✅ Has no instance state.
- ✅ Uses only local variables.
- ✅ Delegates to thread-safe primitives `Thread::Queue`, `Mutex`, etc.
- ✅ The object itself is frozen.

### When in Doubt

If you're unsure whether a class is thread-safe:
1. **Mark it as unsafe** (`ASYNC_SAFE = false`) - let the monitoring catch any issues.
2. **Run your tests** with monitoring enabled.
3. **If no violations occur** after thorough testing, it's likely safe.
4. **Review the code** for the patterns above.

## How It Works

1. **Default Assumption**: All objects follow a single-owner model (not thread-safe).
2. **TracePoint Monitoring**: Tracks which fiber/thread first accesses each object.
3. **Violation Detection**: Raises an exception when a different fiber/thread accesses the same object.
4. **Explicit Safety**: Objects/methods can be marked as thread-safe to allow concurrent access.
5. **Zero Overhead**: Monitoring is only active when explicitly enabled.

## Use Cases

- **Detecting concurrency bugs** in development and testing.
- **Validating thread safety assumptions** in async/fiber-based code.
- **Finding race conditions** before they cause production issues.
- **Educational tool** for learning about thread safety in Ruby.

## Performance

- **Zero overhead when disabled** - TracePoint is not activated.
- **Minimal overhead when enabled** - suitable for development/test environments.
- **Not recommended for production** - use only in development/testing.
