assert = require("assert")
HashMap = require("./hash_map")

h = new HashMap([[1, "v1"]])
h.set("a", "v2")
h.set("a", "v3")
h.set([1, 2, 3], "v4")
assert.equal(h.get(1), "v1")
assert.equal(h.get("a"), "v3")
assert.equal(h.get([1, 2, 3]), "v4")
assert.equal(h.get(2, "v5"), "v5")
assert.ok(h.hasKey(1))
assert.ok(h.hasKey("a"))
assert.ok(h.hasKey([1, 2, 3]))
assert.ok(!h.hasKey(2))
seen1 = false
seen2 = false
seen3 = false
h.forEach (k, v) =>
  if k == 1 && v == "v1"
    seen1 = true
  else if k == "a" && v == "v3"
    seen2 = true
  else if k.length == 3 && k[0] == 1 && k[1] == 2 && k[2] == 3 && v == "v4"
    seen3 = true
  else
    assert.ok(false)
assert.ok(seen1)
assert.ok(seen2)
assert.ok(seen3)
