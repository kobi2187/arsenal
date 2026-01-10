# Arsenal Documentation

## Overview

Arsenal is a universal low-level Nim library providing atomic, composable, swappable primitives for high-performance systems programming.

## Modules

### Platform
- [config](platform/config.md) - CPU feature detection
- [strategies](platform/strategies.md) - Optimization strategies

### Concurrency (WIP)
- atomics - Lock-free atomic operations
- coroutines - Lightweight coroutines
- channels - CSP-style channels
- sync - Synchronization primitives

### Performance
- memory - High-performance allocators
- hashing - Fast hash functions
- datastructures - Swiss tables and filters

## Getting Started

See [README.md](../README.md) for installation and basic usage.

## API Reference

Generate API docs with:
```bash
nim doc src/arsenal.nim
```

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md)