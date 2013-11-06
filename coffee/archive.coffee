fs = require("fs")
Action = require("./action")
Game = require("./game")

class Archive extends Game

  constructor: (path) ->
    @_lines = fs.readFileSync(path).toString("utf-8").split(/\n/)

  play: (onAction) ->
    for line in @_lines
      if line
        action = Action.fromJson(line, this)
        @updateState(action)
        onAction(action)

module.exports = Archive
