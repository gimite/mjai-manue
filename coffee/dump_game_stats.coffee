Archive = require("./archive")
Game = require("./game")
ShantenAnalysis = require("./shanten_analysis")
Util = require("./util")

class BasicCounter

  constructor: ->
    @numKyokus = 0
    @numTurnsFreqs = (0 for _ in [0...18])
    @numRyukyokus = 0
    @totalHoraPoints = 0
    @numHoras = 0
    @numTsumoHoras = 0

  onAction: (action, game) ->
    switch action.type
      when "hora"
        ++@numHoras
        if action.actor == action.target
          ++@numTsumoHoras
        @totalHoraPoints += action.horaPoints
      when "ryukyoku"
        ++@numRyukyokus
      when "end_kyoku"
        ++@numKyokus
        ++@numTurnsFreqs[Math.floor((Game.NUM_INITIAL_PIPAIS - game.numPipais()) / 4)]

class HoraPointsCounter

  constructor: ->
    @koFreqs = {total: 0}
    @oyaFreqs = {total: 0}

  onAction: (action, game) ->
    switch action.type
      when "hora"
        freqs = (if action.actor == game.oya() then @oyaFreqs else @koFreqs)
        ++freqs.total
        if !(action.horaPoints of freqs)
          freqs[action.horaPoints] = 0
        ++freqs[action.horaPoints]

class YamitenCounter

  constructor: ->
    @stats = {}

  onAction: (action, game) ->
    switch action.type
      when "dahai"
        if action.actor.reachState != "none"
          return
        numTurns = Math.floor(game.numPipais() / 4)
        numFuros = action.actor.furos.length
        key = "#{numTurns},#{numFuros}"
        if !(key of @stats)
          @stats[key] = {total: 0, tenpai: 0}
        ++@stats[key].total
        if game.isTenpai(action.actor)
          ++@stats[key].tenpai

class RyukyokuTenpaiCounter

  constructor: ->
    @total = 0
    @tenpai = 0
    @noten = 0
    @tenpaiTurnDistribution = {}
    i = 0
    while i <= Game.FINAL_TURN
      @tenpaiTurnDistribution[i] = 0
      i += 1 / 4

  onAction: (action, game) ->
    switch action.type
      when "start_kyoku"
        @tenpaiTurns = (null for _ in [0...4])
      when "dahai"
        # TODO Support kokushimuso and chitoitsu
        if @tenpaiTurns[action.actor.id] == null && game.isTenpai(action.actor)
          @tenpaiTurns[action.actor.id] = game.turn()
      when "ryukyoku"
        for player in game.players()
          ++@total
          if action.tenpais[player.id]
            ++@tenpai
            ++@tenpaiTurnDistribution[@tenpaiTurns[player.id]]
          else
            ++@noten

basic = new BasicCounter()
horaPoints = new HoraPointsCounter()
yamiten = new YamitenCounter()
ryukyokuTenpai = new RyukyokuTenpaiCounter()
counters = [basic, horaPoints, yamiten, ryukyokuTenpai]

if process.argv.length > 2
  patterns = process.argv[2...]
else
  patterns = ["../data/houou_mjson.*/200912/*.mjson.gz"]

Util.globAll patterns, (err, paths) =>
  if err
    throw new Error(printf("Error in glob: %O", err))
  archive = new Archive(paths)
  onAction = (action) =>
    if action.type == "error"
      throw new Error("error in the log: #{paths[i]}")
    for counter in counters
      counter.onAction(action, archive)
  onEnd = =>
    stats = {
      numHoras: basic.numHoras,
      numTsumoHoras: basic.numTsumoHoras,
      numTurnsDistribution: (f / basic.numKyokus for f in basic.numTurnsFreqs),
      ryukyokuRatio: basic.numRyukyokus / basic.numKyokus,
      averageHoraPoints: basic.totalHoraPoints / basic.numHoras,
      koHoraPointsFreqs: horaPoints.koFreqs,
      oyaHoraPointsFreqs: horaPoints.oyaFreqs,
      yamitenStats: yamiten.stats,
      ryukyokuTenpaiStat: {
        total: ryukyokuTenpai.total,
        tenpai: ryukyokuTenpai.tenpai,
        noten: ryukyokuTenpai.noten,
        tenpaiTurnDistribution: ryukyokuTenpai.tenpaiTurnDistribution,
      },
    }
    console.log(JSON.stringify(stats))
  archive.play(onAction, onEnd)
