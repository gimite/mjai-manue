fs = require("fs")
zlib = require("zlib")
Action = require("./action")
Game = require("./game")

class Archive extends Game

  constructor: (paths) ->
    if typeof(paths) == "string"
      @_paths = [paths]
    else
      @_paths = paths

  playLight: (onAction) ->
    for i in [0...@_paths.length]
      if @_paths.length > 1
        console.error("#{i}/#{@_paths.length}")  # kari
      data = fs.readFileSync(@_paths[i])
      if @_paths[i].match(/\.gz$/)
        data = zlib.gunzipSync(data)
      for line in data.toString("utf-8").split(/\n/)
        if line
          onAction(JSON.parse(line), this)

  play: (onAction) ->
    onLightAction = (lightAction) =>
      action = Action.fromPlain(lightAction, this)
      @updateState(action)
      onAction(action)
    @playLight(onLightAction)

  getLightActions: ->
    actins = []
    @playLight (action) ->
      actions.push(action)
    return actions

module.exports = Archive
