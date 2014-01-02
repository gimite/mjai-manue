assert = require("assert")
printf = require("printf")
Util = require("./util")
HashMap = require("./hash_map")

class ProbDist

  constructor: (arg) ->
    if arg.constructor == HashMap
      @_dist = arg
    else
      @_dist = new HashMap([[arg, 1]])

  expected: ->
    result = null
    for [value, prob] in @_dist
      weighted = ProbDist.mult(value, prob)
      if result == null
        result = weighted
      else
        result = ProbDist.add(result, weighted)
    return result

  toString: ->
    rows = []
    @_dist.forEach (v, p) =>
      rows.push(printf("%O: %.3f", v, p))
    return printf("{%s}", rows.join(", "))

ProbDist.add = (lhs, rhs) ->
  if lhs.constructor == ProbDist || rhs.constructor == ProbDist
    if lhs.constructor != ProbDist
      lhs = new ProbDist(lhs)
    if rhs.constructor != ProbDist
      rhs = new ProbDist(rhs)
    dist = new HashMap()
    lhs.dist().forEach (v1, p1) =>
      rhs.dist().forEach (v2, p2) =>
        v = ProbDist.add(v1, v2)
        dist.set(v, dist.get(v, 0) + p1 * p2)
    return new ProbDist(dist)
  else if typeof(lhs) == "object" && lhs.length && typeof(rhs) == "object" && rhs.length
    assert.equal(lhs.length, rhs.length)
    return (lhs[i] + rhs[i] for i in [0...lhs.length])
  else if typeof(lhs) == "number" && typeof(rhs) == "number"
    return lhs + rhs
  else
    throw new Error(printf("Unexpected types: %O, %O", lhs, rhs))

ProbDist.mult = (lhs, rhs) ->
  if typeof(lhs) == "object" && lhs.length && typeof(rhs) == "number"
    return (v * rhs for v in lhs)
  else if typeof(lhs) == "number" && typeof(rhs) == "number"
    return lhs * rhs
  else
    throw new Error(printf("Unexpected types: %O, %O", lhs, rhs))

ProbDist.merge = (items) ->
  dist = new HashMap()
  for [pd, prob] in items
    pd.dist().forEach (v, p) =>
      console.log(v, p, prob)
      dist.set(v, dist.get(v, 0) + p * prob)
  return new ProbDist(dist)

Util.attrReader(ProbDist, ["dist"])

module.exports = ProbDist
