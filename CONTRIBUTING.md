# Contributing to Arsenal

Thank you for your interest in contributing to Arsenal! This document provides guidelines for contributors.

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/arsenal.git
   cd arsenal
   ```

2. Install Nim 2.0+ and dependencies:
   ```bash
   nimble install -y
   ```

3. Build and test:
   ```bash
   nimble build
   nimble test
   nimble bench
   ```

## Code Style

- Follow Nim's official style guide
- Use `nimpretty` for formatting:
  ```bash
  nimpretty src/ tests/ benchmarks/ examples/
  ```
- Use descriptive variable names
- Add documentation comments for public APIs
- Prefer compile-time computation where appropriate

## Testing

- Write unit tests for all new functionality
- Tests go in `tests/` directory
- Run tests with `nimble test`
- Aim for high test coverage

## Benchmarking

- Performance is critical for Arsenal
- Add benchmarks for performance-sensitive code
- Run benchmarks with `nimble bench`
- Compare against baseline implementations

## Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes with tests and benchmarks
4. Run the full test suite: `nimble test && nimble bench`
5. Format code: `nimpretty --check src/ tests/ benchmarks/ examples/`
6. Commit with descriptive messages
7. Push to your fork and create a PR

## Architecture Decisions

Arsenal follows these key patterns:

1. **Unsafe + Safe Wrappers**: Every module provides both low-level unsafe primitives and high-level safe wrappers
2. **Strategy-Based Optimization**: Code adapts behavior based on optimization strategy (Throughput, Latency, etc.)
3. **Platform-Specific Dispatch**: Best implementation selected at compile-time based on CPU features
4. **Zero-Cost Abstractions**: High-level APIs compile to efficient machine code

## Performance Requirements

- Memory allocators: >10x faster than system malloc
- Hash functions: >10 GB/s throughput
- Lock-free queues: >1M ops/sec per producer/consumer
- Coroutines: <20ns context switch time

## Licensing

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

Open an issue or discussion on GitHub for questions about contributing.