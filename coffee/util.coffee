glob = require("glob")
assert = require("assert")
printf = require("printf")

Util =

  attrReader: (cls, names) ->
    names.forEach (name) ->
      cls.prototype[name] = (-> this["_#{name}"])

  attrAccessor: (cls, names) ->
    Util.attrReader(cls, names)
    names.forEach (name) ->
      capital = name.replace(/^./, (s) -> s.toUpperCase())
      cls.prototype["set#{capital}"] = ((a) -> this["_#{name}"] = a)

  all: (array, func) ->
    for v in array
      if !func(v) then return false
    return true

  any: (array, func) ->
    for v in array
      if func(v) then return true
    return false

  count: (array, func) ->
    n = 0
    for v in array
      if func(v) then ++n
    return n

  mergeObjects: (lhs, rhs) ->
    result = {}
    for k, v of lhs
      result[k] = v
    for k, v of rhs
      result[k] = v
    return result

  camelCase: (name) ->
    return name.replace(/_(.)/g, (_, ch) -> ch.toUpperCase())

  shuffle: (array, random, n = array.length) ->
    for i in [0...n]
      j = i + Math.floor(random() * (array.length - i))
      tmp = array[i]
      array[i] = array[j]
      array[j] = tmp
    return array

  globAll: (patterns, callback, i = 0, result = []) ->
    if i >= patterns.length
      callback(undefined, result)
    else
      glob patterns[i], (err, paths) =>
        if err
          callback(err)
        else
          for path in paths
            result.push(path)
          Util.globAll(patterns, callback, i + 1, result)

  assertAlmostEqual: (actual, expected, error = 0.0001) ->
    assert.ok(Math.abs(actual - expected) <= error, printf("%O != %O", actual, expected))

  formatObjectsAsTable: (objects, columns) ->
    arrays = [c[0] for c in columns]
    for object in objects
      arrays.push(printf(c[2], object[c[1]]) for c in columns)
    return Util.formatArraysAsTable(arrays)

  formatArraysAsTable: (arrays) ->
    widths = (0 for _ in [0...arrays[0].length])
    for array in arrays
      for i in [0...array.length]
        widths[i] = Math.max(widths[i], array[i].length)
    result = ""
    for array in arrays
      result += "| "
      for i in [0...array.length]
        w = widths[i]
        result += printf("%+#{w}s | ", array[i])
      result += "\n"
    return result


module.exports = Util
