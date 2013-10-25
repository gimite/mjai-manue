url = require("url")
net = require("net")
Action = require("./action")
PuppetPlayer = require("./puppet_player")
Pai = require("./pai")
Util = require("./util")

class TCPClientGame

  constructor: (@_params) ->

  play: ->
    @_urlFields = url.parse(@_params.url)
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
        if action.type == "start_game"
          @_myId = action.id
          @_players = for i in [0...4]
              if i == @_myId then @_params.player else new PuppetPlayer()
          for player in @_players
            player.setGame(this)
        responses = @doAction(action)
        if action.type == "end_game"
          @_socket.end()
          return
        response = responses && responses[@_myId]
        responseJson =
            (if response then response.toJson() else JSON.stringify({type: "none"}))
    console.log("->\t#{responseJson}")
    @_socket.write("#{responseJson}\n")

  doAction: (action) ->
    @updateState(action)
    responses = for i in [0...4]
        @_players[i].respondToAction(@actionInView(action, i))
    return responses

  updateState: (action) ->
    for i in [0...4]
      @_players[i].updateState(@actionInView(action, i))
      console.log("[#{i}] tehai: " + Pai.paisToStr(@_players[i].tehais()))
      console.log("       ho: " + Pai.paisToStr(@_players[i].ho()))

  actionInView: (action, playerId) ->
    if action.type == "start_game"
      return action.merge({id: playerId})
    else
      return action

Util.attrReader(TCPClientGame, ["players"])

module.exports = TCPClientGame
