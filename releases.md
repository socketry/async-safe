# Releases

## Unreleased

  - `Thread::Queue` transfers ownership of objects popped from it.
  - Add support for `logger:` option in `Async::Safe.enable!` which logs violations instead of raising errors.

## v0.1.0

  - Implement TracePoint-based ownership tracking.
  - Add `Async::Safe::Concurrent` module for marking thread-safe classes.
  - Add `thread_safe` class method for marking thread-safe methods.
  - Add `Async::Safe.transfer` for explicit ownership transfer
  - Add violation detection and reporting
  - Zero overhead when monitoring is disabled
