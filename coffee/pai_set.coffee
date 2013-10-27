Pai = require("./pai")
Util = require("./util")

class PaiSet

  constructor: (arg) ->
    if arg.array
      @_array = arg.array
    else
      @_array = (0 for _ in [0...Pai.NUM_IDS])
      for pai in arg
        ++@_array[pai.id()]

  toString: ->
    pais = []
    for pid in [0...Pai.NUM_IDS]
      for i in [0...@_array[pid]]
        pais.push(new Pai(pid))
    return pais.join(" ")

Util.attrReader(PaiSet, ["array"])

module.exports = PaiSet
