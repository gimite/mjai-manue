Archive = require("./archive")
Game = require("./game")
ShantenAnalysis = require("./shanten_analysis")

class BasicCounter

  constructor: ->
    @numKyokus = 0
    @numTurnsFreqs = (0 for _ in [0...18])
    @numRyukyokus = 0
    @totalHoraPoints = 0
    @numHoras = 0

  onAction: (action, game) ->
    switch action.type
      when "hora"
        ++@numHoras
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

class ScoreCounter

  constructor: ->
    @stats = {}
    @kyokuStats = []

  onAction: (action, game) ->
    switch action.type
      when "end_kyoku"
        @kyokuStats.push({
          kyokuName: game.bakaze().toString() + game.kyokuNum(),
          scores: (p.score for p in game.players()),
        })
      when "end_game"
        rankedPlayers = game.rankedPlayers()
        for rank1 in [0...4]
          for rank2 in [0...4]
            if rank1 == rank2 then continue
            player1 = rankedPlayers[rank1]
            player2 = rankedPlayers[rank2]
            pos1 = game.getDistance(player1, game.chicha())
            pos2 = game.getDistance(player2, game.chicha())
            for stat in @kyokuStats
              scoreDiff = stat.scores[player1.id] - stat.scores[player2.id]
              scoreDiffFloor = Math.floor(scoreDiff / 1000) * 1000
              key = "#{stat.kyokuName},#{pos1},#{pos2},#{scoreDiffFloor}"
              if !(key of @stats)
                @stats[key] = {total: 0, win: 0}
              ++@stats[key].total
              if rank1 < rank2
                ++@stats[key].win

        @kyokuStats = []

basic = new BasicCounter()
horaPoints = new HoraPointsCounter()
yamiten = new YamitenCounter()
ryukyokuTenpai = new RyukyokuTenpaiCounter()
score = new ScoreCounter()
counters = [basic, horaPoints, yamiten, ryukyokuTenpai, score]

archive = new Archive(process.argv[2...])
onAction = (action) =>
  if action.type == "error"
    throw new Error("error in the log: #{paths[i]}")
  for counter in counters
    counter.onAction(action, archive)
onEnd = =>
  stats = {
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
    scoreStats: score.stats,
  }
  console.log(JSON.stringify(stats))
archive.play(onAction, onEnd)

