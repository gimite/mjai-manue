Util = require("./util")

class Furo

  constructor: (params) ->
    @_type = params.type
    @_taken = params.taken
    @_consumed = params.consumed
    @_target = params.target

Util.attrReader(Furo, "type", "taken", "consumed", "target")

module.exports = Furo
