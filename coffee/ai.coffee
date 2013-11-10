Util = require("./util")
Action = require("./action")

class AI

  initialize: (@_game, @_player) ->
    @_log = ""

  createAction: (action) ->
    if action.constructor != Action
      action = new Action(action)
    action = action.merge({actor: @_player, log: @_log})
    @_log = ""
    return action

  log: (str) ->
    console.log(str)
    @_log += str + "\n"

Util.attrReader(AI, ["game", "player"])

module.exports = AI
