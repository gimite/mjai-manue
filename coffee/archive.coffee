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

  playLight: (onAction, onEnd = null, i = 0) ->
    @_buffer = ""
    if i >= @_paths.length
      if onEnd then onEnd()
    else
      console.error("#{i}/#{@_paths.length}")  # kari
      stream = fs.createReadStream(@_paths[i])
      if @_paths[i].match(/\.gz$/)
        stream = stream.pipe(zlib.createGunzip())
      stream.on "data", (buf) =>
        @_buffer += buf.toString("utf-8")
      stream.on "end", =>
        for line in @_buffer.split(/\n/)
          if line
            onAction(JSON.parse(line), this)
        @playLight(onAction, onEnd, i + 1)

  play: (onAction, onEnd) ->
    onLightAction = (lightAction) =>
      action = Action.fromPlain(lightAction)
      @updateState(action)
      onAction(action)
    @playLight(onLightAction, onEnd)

module.exports = Archive
