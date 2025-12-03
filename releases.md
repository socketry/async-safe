# Releases

## v0.5.0

  - More conservative tracking of objects using call/return for ownership transfer.
  - Introduced guard concept for splitting ownership within a single object, e.g. independently concurrent readable and writable parts of an object.

## v0.4.0

  - Improved `Async::Safe.transfer` to recursively transfer ownership of tracked instance variables.

## v0.3.2

  - Better error message.

## v0.3.0

  - Inverted default model: classes are async-safe by default, use `ASYNC_SAFE = false` to enable tracking.
  - Added flexible `ASYNC_SAFE` constant support: boolean, hash, or array configurations.
  - Added `Class#async_safe!` method for marking classes.
  - Added `Class#async_safe?(method)` method for querying safety.
  - Added `Class.async_safe_traverse` for custom deep transfer traversal (opt-in).
  - Improved `Async::Safe.transfer` to use shallow transfer by default with opt-in deep traversal.
  - Mark built-in collections (`Array`, `Hash`, `Set`) as single-owner with deep traversal support.
  - Removed logger feature: always raises `ViolationError` exceptions.
  - Removed `Async::Safe::Concurrent` module: use `async_safe!` instead.

## v0.2.0

  - `Thread::Queue` transfers ownership of objects popped from it.
  - Add support for `logger:` option in `Async::Safe.enable!` which logs violations instead of raising errors.

## v0.1.0

  - Implement TracePoint-based ownership tracking.
  - Add `Async::Safe::Concurrent` module for marking thread-safe classes.
  - Add `thread_safe` class method for marking thread-safe methods.
  - Add `Async::Safe.transfer` for explicit ownership transfer
  - Add violation detection and reporting
  - Zero overhead when monitoring is disabled
