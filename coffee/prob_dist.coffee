assert = require("assert")
printf = require("printf")
Util = require("./util")
HashMap = require("./hash_map")

class ProbDist

  constructor: (arg) ->
    @_dist = new HashMap()
    if arg.constructor == HashMap
      arg.forEach (value, prob) =>
        if prob > 0
          @_dist.set(value, prob)
    else
      @_dist.set(arg, 1)

  expected: ->
    result = null
    @_dist.forEach (value, prob) =>
      weighted = ProbDist.mult(prob, value)
      if result == null
        result = weighted
      else
        result = ProbDist.add(result, weighted)
    return result

  replace: (oldValue, newPb) ->
    dist = new HashMap()
    prob = 0
    @_dist.forEach (v, p) =>
      if ProbDist.equal(v, oldValue)
        prob = p
      else
        dist.set(v, p)
    newPb.dist().forEach (v, p) ->
      dist.set(v, dist.get(v, 0) + p * prob)
    return new ProbDist(dist)

  mapValue: (map) ->
    dist = new HashMap()
    @_dist.forEach (v, p) =>
      newValue = map(v)
      dist.set(newValue, dist.get(newValue, 0) + p)
    return new ProbDist(dist)

  toString: ->
    a = []
    @_dist.forEach (v, p) =>
      a.push({v: v, p: p})
    a.sort((x, y) => y.p - x.p)
    return printf("{\n%s}", (printf("  %O: %.3f,\n", x.v, x.p) for x in a).join(""))

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
  if lhs.constructor == ProbDist || rhs.constructor == ProbDist
    if lhs.constructor != ProbDist
      lhs = new ProbDist(lhs)
    if rhs.constructor != ProbDist
      rhs = new ProbDist(rhs)
    dist = new HashMap()
    lhs.dist().forEach (v1, p1) =>
      rhs.dist().forEach (v2, p2) =>
        v = ProbDist.mult(v1, v2)
        dist.set(v, dist.get(v, 0) + p1 * p2)
    return new ProbDist(dist)
  else if typeof(lhs) == "number" && typeof(rhs) == "object" && rhs.length
    return (lhs * v for v in rhs)
  else if typeof(lhs) == "number" && typeof(rhs) == "number"
    return lhs * rhs
  else
    throw new Error(printf("Unexpected types: %O, %O", lhs, rhs))

ProbDist.merge = (items) ->
  dist = new HashMap()
  for [pd, prob] in items
    pd.dist().forEach (v, p) =>
      dist.set(v, dist.get(v, 0) + p * prob)
  return new ProbDist(dist)

ProbDist.equal = (lhs, rhs) ->
  return JSON.stringify(lhs) == JSON.stringify(rhs)

Util.attrReader(ProbDist, ["dist"])

module.exports = ProbDist
