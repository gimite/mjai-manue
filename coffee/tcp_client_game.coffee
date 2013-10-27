url = require("url")
net = require("net")
Action = require("./action")
Pai = require("./pai")
Furo = require("./furo")
Util = require("./util")
ShantenAnalysis = require("./shanten_analysis")

class TCPClientGame

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
        response = @doAction(action)
        if action.type == "end_game"
          @_socket.end()
          return
        responseJson =
            (if response then response.toJson() else JSON.stringify({type: "none"}))
    console.log("->\t#{responseJson}")
    @_socket.write("#{responseJson}\n")

  doAction: (action) ->
    @updateState(action)
    return @_ai.respondToAction(action)

  updateState: (action) ->

    @_previousAction = @_currentAction
    @_currentAction = action
    if action.actor then @_actor = action.actor

    switch action.type
      when "start_game"
        @_myId = action.id
        @_players = ({id: i} for i in [0...4])
        @_ai.initialize(this, @_players[action.id])
      when "start_kyoku"
        @_numPipais = Pai.NUM_IDS * 4 - 13 * 4 - 14
      when "tsumo"
        --@_numPipais

    for player in @_players

      # This is specially handled here because it's not an anpai if the dahai is followed by
      # a hora.
      if @_previousAction &&
          @_previousAction.type == "dahai" &&
          @_previousAction.actor != player &&
          action.type != "hora"
        player.extraAnpais.push(@_previousAction.pai)

      switch action.type
        when "start_game"
          if action.names
            player.name = action.names[player.id]
          player.score = 25000
          player.tehais = null
          player.furos = null
          player.ho = null
          player.sutehais = null
          player.extraAnpais = null
          player.reachState = null
          player.reachHoIndex = null
        when "start_kyoku"
          player.tehais = action.tehais[player.id]
          player.furos = []
          player.ho = []
          player.sutehais = []
          player.extraAnpais = []
          player.reachState = "none"
          player.reachHoIndex = null

      if action.actor == player
        switch action.type
          when "tsumo"
            player.tehais.push(action.pai)
          when "dahai"
            @deleteTehai(player, action.pai)
            player.tehais.sort(Pai.compare)
            player.ho.push(action.pai)
            player.sutehais.push(action.pai)
            if player.reachState != "accepted" then player.extraAnpais = []
          when "chi", "pon", "daiminkan", "ankan"
            for pai in action.consumed
              @deleteTehai(player, pai)
            player.furos.push(new Furo({
                type: action.type,
                taken: action.pai,
                consumed: action.consumed,
                target: action.target,
            }))
          when "kakan"
            @deleteTehai(player, action.pai)
            ponIndex = null
            for i in [0...player.furos.length]
              if player.furos[i].type == "pon" && player.furos[i].taken().hasSameSymbol(action.pai)
                ponIndex = i
                break
            if ponIndex == null
              throw "should not happen"
            player.furos[ponIndex] = new Furo({
                type: "kakan",
                taken: player.furos[ponIndex].taken,
                consumed: player.furos[ponIndex].consumed.concat([action.pai]),
                target: player.furos[ponIndex].target,
            })
          when "reach"
            player.reachState = "declared"
          when "reach_accepted"
            player.reachState = "accepted"
            player.reachHoIndex = player.ho.length - 1

      if action.target == player
        switch action.type
          when "chi", "pon", "daiminkan"
            pai = player.ho.pop()
            if pai != action.pai
              throw "should not happen"

      if action.scores
        player.score = action.scores[player.id]

      console.log("[#{player.id}] tehai: " + Pai.paisToStr(player.tehais))
      console.log("       ho: " + Pai.paisToStr(player.ho))

  canHora: (player, shantenAnalysis) ->
    action = @_currentAction
    if action.type == "tsumo" && action.actor == player
      horaType = "tsumo"
      pais = player.tehais
    else if (action.type == "dahai" || action.type == "kakan") && action.actor != player
      horaType = "ron"
      pais = player.tehais.concat([action.pai])
    else
      return false
    if !shantenAnalysis
      shantenAnalysis = new ShantenAnalysis(pai.id() for pai in pais)  # TODO check only hora
    # horaAction = new Action(
    #     type: "hora", actor: player, target: action.actor, pai: action.pai)
    # return shantenAnalysis.shanten() == -1 &&
    #     getHora(horaAction, {previousAction: action}).valid() &&
    #     (horaType == "tsumo" || !@isFuriten(player)
    # TODO Implement yaku detection
    return shantenAnalysis.shanten() == -1 &&
        player.reachState == "accepted" &&
        (horaType == "tsumo" || !@isFuriten(player))

  canReach: (player, shantenAnalysis) ->
    if !shantenAnalysis
      # TODO check only tenpai
      shantenAnalysis = new ShantenAnalysis(pai.id() for pai in player.tehais)
    return @_currentAction.type == "tsumo" &&
        @_currentAction.actor == player &&
        shantenAnalysis.shanten() <= 0 &&
        player.furos.length == 0 &&
        player.reachState == "none" &&
        @_numPipais >= 4 &&
        player.score >= 1000

  isFuriten: (player) ->
    if player.tehais.length % 3 != 1 then return false
    if Pai.UNKNOWN.isIn(player.tehais) then return false
    shantenAnalysis = new ShantenAnalysis(player.tehais)  # TODO check only tenpai
    if shantenAnalysis.shanten() > 0 then return false
    anpais = @anpais(player)
    for goal in shantenAnalysis.goals()
      for pid in [0...Pai.NUM_IDS]
        if goal.requiredVector[pid] > 0 && new Pai(pid).isIn(anpais)
          return true
    return false

  anpais: (player) ->
    return player.sutehais.concat(player.extraAnpais)

  deleteTehai: (player, pai) ->
    paiIndex = null
    for i in [0...player.tehais.length]
      if player.tehais[i].equal(pai) || player.tehais[i].equal(Pai.UNKNOWN)
        paiIndex = i
        break
    if paiIndex == null
      throw "trying to delete #{pai} which is not in tehais: #{player.tehais}"
    player.tehais.splice(paiIndex, 1)

Util.attrReader(TCPClientGame, ["players"])

module.exports = TCPClientGame
