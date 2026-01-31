# Package
version       = "0.1.0"
author        = "Kobi"
description   = "Universal low-level Nim library - atomic, composable, swappable primitives"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 1.6.0"

# Tasks
task test, "Run all tests":
  exec "nim c -r tests/test_all.nim"

task bench, "Run benchmarks":
  exec "nim c -d:release -d:danger -r benchmarks/bench_all.nim"

task format, "Format code with nimpretty":
  exec "nimpretty src/ tests/ benchmarks/ examples/"

task lint, "Check code formatting":
  exec "nimpretty --check src/ tests/ benchmarks/ examples/"

task docs, "Generate documentation":
  exec "nim doc --outdir:docs/api src/arsenal.nim"
