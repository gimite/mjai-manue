Pai = require("./pai")
Util = require("./util")

class PaiSet

  constructor: (arg) ->
    if !arg
      @_array = (0 for _ in [0...Pai.NUM_IDS])
    else if arg.array
      @_array = arg.array
    else
      @_array = (0 for _ in [0...Pai.NUM_IDS])
      @addPais(arg)

  toPais: ->
    pais = []
    for pid in [0...Pai.NUM_IDS]
      for i in [0...@_array[pid]]
        pais.push(new Pai(pid))
    return pais

  addPai: (pai, n) ->
    @_array[pai.id()] += n

  addPais: (pais) ->
    for pai in pais
      ++@_array[pai.id()]

  removePaiSet: (paiSet) ->
    otherArray = paiSet.array()
    for pid in [0...Pai.NUM_IDS]
      @_array[pid] -= otherArray[pid]

  toString: ->
    return @toPais().join(" ")

PaiSet.getAll = ->
  return new PaiSet(array: (4 for _ in [0...Pai.NUM_IDS]))

Util.attrReader(PaiSet, ["array"])

module.exports = PaiSet
