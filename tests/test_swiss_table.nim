## Unit Tests for Swiss Table
## ===========================

import std/unittest
import std/options
import ../src/arsenal/datastructures/hashtables/swiss_table

suite "Swiss Table - Initialization":
  test "init creates empty table":
    var table = SwissTable[string, int].init()

    check table.len == 0
    check table.capacity >= 16  # Minimum capacity

  test "init with custom capacity":
    var table = SwissTable[string, int].init(64)

    check table.len == 0
    check table.capacity >= 64
    # Capacity should be rounded to multiple of 16
    check (table.capacity mod 16) == 0

suite "Swiss Table - Basic Operations":
  test "insert and retrieve single item":
    var table = SwissTable[string, int].init()

    table["hello"] = 42

    check table.len == 1
    check table["hello"] == 42

  test "insert multiple items":
    var table = SwissTable[string, int].init()

    table["one"] = 1
    table["two"] = 2
    table["three"] = 3

    check table.len == 3
    check table["one"] == 1
    check table["two"] == 2
    check table["three"] == 3

  test "update existing key":
    var table = SwissTable[string, int].init()

    table["key"] = 10
    check table["key"] == 10

    table["key"] = 20  # Update
    check table["key"] == 20
    check table.len == 1  # Still only one item

  test "contains check":
    var table = SwissTable[string, int].init()

    table["exists"] = 100

    check table.contains("exists") == true
    check table.contains("missing") == false

  test "find returns Some for existing key":
    var table = SwissTable[string, int].init()

    table["test"] = 999

    let result = table.find("test")
    check result.isSome
    check result.get[] == 999

  test "find returns None for missing key":
    var table = SwissTable[string, int].init()

    let result = table.find("missing")
    check result.isNone

suite "Swiss Table - Deletion":
  test "delete existing key":
    var table = SwissTable[string, int].init()

    table["key1"] = 1
    table["key2"] = 2

    let deleted = table.delete("key1")

    check deleted == true
    check table.len == 1
    check table.contains("key1") == false
    check table.contains("key2") == true

  test "delete non-existing key":
    var table = SwissTable[string, int].init()

    table["key"] = 1

    let deleted = table.delete("missing")

    check deleted == false
    check table.len == 1

  test "delete and reinsert":
    var table = SwissTable[string, int].init()

    table["key"] = 1
    discard table.delete("key")
    table["key"] = 2

    check table["key"] == 2
    check table.len == 1

suite "Swiss Table - Clear":
  test "clear removes all items":
    var table = SwissTable[string, int].init()

    for i in 0..<100:
      table[$i] = i

    check table.len == 100

    table.clear()

    check table.len == 0
    check table.contains("0") == false
    check table.contains("99") == false

  test "clear and reuse table":
    var table = SwissTable[string, int].init()

    table["a"] = 1
    table["b"] = 2
    table.clear()

    table["c"] = 3
    table["d"] = 4

    check table.len == 2
    check table["c"] == 3
    check table["d"] == 4

suite "Swiss Table - Iteration":
  test "iterate over pairs":
    var table = SwissTable[string, int].init()

    table["one"] = 1
    table["two"] = 2
    table["three"] = 3

    var count = 0
    var sum = 0

    for key, value in table.pairs:
      inc count
      sum += value

    check count == 3
    check sum == 6

  test "iterate over keys":
    var table = SwissTable[string, int].init()

    table["a"] = 1
    table["b"] = 2
    table["c"] = 3

    var keys: seq[string]
    for key in table.keys:
      keys.add(key)

    check keys.len == 3
    check "a" in keys
    check "b" in keys
    check "c" in keys

  test "iterate over values":
    var table = SwissTable[string, int].init()

    table["x"] = 10
    table["y"] = 20
    table["z"] = 30

    var sum = 0
    for value in table.values:
      sum += value

    check sum == 60

  test "empty table iteration":
    var table = SwissTable[string, int].init()

    var count = 0
    for k, v in table.pairs:
      inc count

    check count == 0

suite "Swiss Table - Stress Tests":
  test "insert many items":
    var table = SwissTable[int, int].init()

    for i in 0..<1000:
      table[i] = i * 2

    check table.len == 1000

    # Verify all values
    for i in 0..<1000:
      check table[i] == i * 2

  test "mixed operations":
    var table = SwissTable[string, int].init()

    # Insert
    for i in 0..<100:
      table[$i] = i

    # Update some
    for i in 0..<50:
      table[$i] = i * 10

    # Delete some
    for i in countup(0, 98, 2):  # Delete evens
      discard table.delete($i)

    # Check remaining
    check table.len == 50

    for i in countup(1, 99, 2):  # Odds should remain
      check table.contains($i)

suite "Swiss Table - Collision Handling":
  test "handle hash collisions":
    var table = SwissTable[string, int].init()

    # Insert keys that might hash similarly
    let keys = ["abc", "bca", "cab", "acb", "bac", "cba"]

    for i, key in keys:
      table[key] = i

    check table.len == 6

    # Verify all retrievable
    for i, key in keys:
      check table[key] == i

  test "probe chain works correctly":
    var table = SwissTable[int, int].init(16)  # Small table

    # Fill more than one group
    for i in 0..<32:
      table[i] = i * 10

    # All should be retrievable
    for i in 0..<32:
      check table[i] == i * 10

suite "Swiss Table - Different Value Types":
  test "table with string values":
    var table = SwissTable[int, string].init()

    table[1] = "one"
    table[2] = "two"
    table[3] = "three"

    check table[1] == "one"
    check table[2] == "two"
    check table[3] == "three"

  test "table with composite keys":
    var table = SwissTable[string, string].init()

    table["user:alice"] = "Alice Smith"
    table["user:bob"] = "Bob Jones"

    check table["user:alice"] == "Alice Smith"
    check table["user:bob"] == "Bob Jones"

suite "Swiss Table - Edge Cases":
  test "empty key and value":
    var table = SwissTable[string, string].init()

    table[""] = ""

    check table.len == 1
    check table[""] == ""

  test "accessing non-existent key raises KeyError":
    var table = SwissTable[string, int].init()

    expect(KeyError):
      discard table["missing"]

  test "large keys":
    var table = SwissTable[string, int].init()

    var longKey = ""
    for i in 0..<1000:
      longKey.add('a')

    table[longKey] = 42

    check table[longKey] == 42

  test "zero value storage":
    var table = SwissTable[string, int].init()

    table["zero"] = 0

    check table.contains("zero")
    check table["zero"] == 0

echo "Swiss table tests completed successfully!"
