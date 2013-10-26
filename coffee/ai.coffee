Util = require("./util")
Action = require("./action")

class AI

  initialize: (@_game, @_player) ->

  createAction: (extraParams) ->
    params = {actor: @_player}
    for k, v of extraParams
      params[k] = v
    return new Action(params)

Util.attrReader(AI, ["game", "player"])

module.exports = AI
