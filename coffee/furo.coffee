Util = require("./util")
Pai = require("./pai")

class Furo

  constructor: (params) ->
    @_type = params.type
    @_taken = params.taken
    @_consumed = params.consumed
    @_target = params.target

  pais: ->
    result = (if @_taken then [@_taken] else []).concat(@_consumed)
    result.sort(Pai.compare)
    return result

Util.attrReader(Furo, ["type", "taken", "consumed", "target"])

module.exports = Furo
