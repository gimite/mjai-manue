url = require("url")
net = require("net")
Action = require("./action")
Pai = require("./pai")
Furo = require("./furo")
Game = require("./game")
Util = require("./util")
ShantenAnalysis = require("./shanten_analysis")

class TCPClientGame extends Game

  constructor: (@_params) ->
    @_ai = @_params.ai
    @_urlFields = url.parse(@_params.url)

  play: ->
    @_buffer = ""
    @_socket = net.connect({host: @_urlFields.hostname, port: @_urlFields.port})
    @_socket.on "connect", =>
      console.log("connected")
    @_socket.on("data", (chunk) =>
      lines = chunk.toString().split(/\n/)
      lines[0] = @_buffer + lines[0]
      for i in [0...(lines.length - 1)]
        @onReceiveLine(lines[i])
      @_buffer = lines[lines.length - 1]
    @_socket.on "close", =>
      console.log("closed"))
    @_socket.on "error", (e) =>
      console.log("tcp error: #{e.message}")

  onReceiveLine: (line) ->
    console.log("<-\t#{line}")
    action = Action.fromJson(line, this)
    switch action.type
      when "hello"
        responseJson = JSON.stringify({
            type: "join", 
            name: @_params.name, 
            room: @_urlFields.path.substr(1),
        })
      when "error"
        @_socket.end()
        return
      else
        @updateState(action)
        @printState()
        response = @_ai.respondToAction(action)
        if action.type == "end_game"
          @_socket.end()
          return
        responseJson =
            (if response then response.toJson() else JSON.stringify({type: "none"}))
    console.log("->\t#{responseJson}")
    @_socket.write("#{responseJson}\n")

  updateState: (action) ->
    super(action)
    switch action.type
      when "start_game"
        @_myId = action.id
        @_ai.initialize(this, @players()[action.id])

module.exports = TCPClientGame
