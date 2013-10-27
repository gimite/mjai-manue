Util = require("./util")

class Furo

  constructor: (params) ->
    @_type = params.type
    @_taken = params.taken
    @_consumed = params.consumed
    @_target = params.target

  pais: ->
    return (if @_taken then [@_taken] else []).concat(@_consumed)

Util.attrReader(Furo, "type", "taken", "consumed", "target")

module.exports = Furo
