assert = require("assert")
printf = require("printf")

# NOTE: This doesn't work for objects because it distinguishes {a: 1, b: 2} and {b: 2, a: 1}.
class HashMap

  constructor: (pairs) ->
    @_data = {}
    if pairs
      for [key, value] in pairs
        @set(key, value)

  set: (key, value) ->
    assert.notEqual(key, undefined)
    assert.notEqual(value, undefined)
    @_data[JSON.stringify(key)] = value

  get: (key, def) ->
    assert.notEqual(key, undefined)
    keyJson = JSON.stringify(key)
    if keyJson of @_data
      return @_data[keyJson]
    else
      return def

  hasKey: (key) ->
    assert.notEqual(key, undefined)
    return JSON.stringify(key) of @_data

  forEach: (callback) ->
    for keyJson, value of @_data
      callback(JSON.parse(keyJson), value)

  toString: ->
    a = []
    @forEach (k, v) =>
      a.push(printf("%O: %O", k, v))
    return printf("HashMap {%s}", a.join(", "))

module.exports = HashMap
