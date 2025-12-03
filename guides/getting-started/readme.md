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

## Concurrent Access Detection

`async-safe` detects **concurrent access** (data races) to objects across fibers. Objects can move freely between fibers - violations are only raised when two fibers try to access the same object simultaneously.

~~~ ruby
Async::Safe.enable!

request = Request.new("http://example.com")
request.process  # Main fiber

Fiber.new do
	# No problem - sequential access is allowed
	request.process  # ✅ OK
end.resume
~~~

However, actual concurrent access is detected:

~~~ ruby
require 'async'

counter = Counter.new
counter.increment

Async do |task|
	task.async do
		counter.increment  # Fiber A accessing
		sleep 0.1  # ... method is still running
	end
	
	task.async do
		sleep 0.05  # Wait for Fiber A to start
		counter.increment  # 💥 Concurrent access detected!
	end
end
~~~

This approach focuses on catching **actual bugs** (data races) while allowing objects to move naturally between fibers.

### Guard-Based Concurrency

For objects with multiple independent operation types (like streams with separate read/write operations), `async_safe?` can return different guard symbols for different operations:

~~~ ruby
class Stream
	def self.async_safe?(method)
		case method
		when :read then :readable
		when :write then :writable
		else false
		end
	end
	
	def read; end
	def write(data); end
end
~~~

This allows:
- ✅ Concurrent `read` and `write` (different guards: `:readable` and `:writable`)
- ❌ Concurrent `read` and `read` (same `:readable` guard)
- ❌ Concurrent `write` and `write` (same `:writable` guard)

Each guard can only be held by one fiber at a time, but different guards can be held concurrently.

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
body.read  # Main fiber

Fiber.schedule do
	body.read  # ✅ OK - sequential access is allowed
end

# But concurrent access is detected:
require 'async'
Async do |task|
	task.async { body.read }  # Two fibers accessing
	task.async { body.read }  # at the same time → ViolationError!
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
