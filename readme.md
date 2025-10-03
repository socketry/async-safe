# Async::Safe

Runtime thread safety monitoring for concurrent Ruby code.

This gem provides a TracePoint-based ownership tracking system that detects when objects are accessed from multiple fibers or threads without proper synchronization. It helps catch concurrency bugs during development and testing with zero overhead in production.

[![Development Status](https://github.com/socketry/async-safe/workflows/Test/badge.svg)](https://github.com/socketry/async-safe/actions?workflow=Test)

## Motivation

Ruby's fiber-based concurrency (via `async`) requires careful attention to object ownership. This gem helps you catch violations of the single-owner model in your test suite, preventing concurrency bugs from reaching production.

Enable it in your tests to get immediate feedback when objects are incorrectly shared across fibers.

## Usage

Please see the [project documentation](https://socketry.github.io/async-safe/) for more details.

  - [Getting Started](https://socketry.github.io/async-safe/guides/getting-started/index) - This guide explains how to use `async-safe` to detect thread safety violations.

## Releases

There are no documented releases.

## See Also

  - [async](https://github.com/socketry/async) - Composable asynchronous I/O for Ruby.
  - [Thread Safety Guide](https://github.com/socketry/async/blob/main/.context/async/thread-safety.md) - Best practices for concurrent Ruby code.

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
