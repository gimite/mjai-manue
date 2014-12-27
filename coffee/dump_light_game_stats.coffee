fs = require("fs")
glob = require("glob")
printf = require("printf")
Game = require("./game")
Archive = require("./archive")
Util = require("./util")

class ScoreCounter

  constructor: ->
    @scores = null
    @stats = {}
    @kyokuStats = []
    @chichaId = 0

  onAction: (action) ->
    if action.scores
      @scores = action.scores
    switch action.type
      when "start_game"
        @scores = [25000, 25000, 25000, 25000]
        @kyokuStats = []
      when "start_kyoku"
        @kyokuStats.push({
          kyokuName: action.bakaze + action.kyoku
          scores: @scores,
        })
      when "end_game"
        for playerId in [0...4]
          pos = @getDistance(playerId, @chichaId)
          for stat in @kyokuStats
            scoreDiff = @scores[playerId] - stat.scores[playerId]
            key = "#{stat.kyokuName},#{pos}"
            if !(key of @stats)
              @stats[key] = {}
            if !(scoreDiff of @stats[key])
              @stats[key][scoreDiff] = 0
            ++@stats[key][scoreDiff]

  getDistance: (playerId1, playerId2) ->
    return (4 + playerId1 - playerId2) % 4


score = new ScoreCounter()
counters = [score]

Util.globAll process.argv[2...], (err, paths) =>
  if err
    throw new Error(printf("Error in glob: %O", err))
  archive = new Archive(paths)
  onAction = (action) =>
    if action.type == "error"
      throw new Error("error in the log: #{paths[i]}")
    for counter in counters
      counter.onAction(action)
  onEnd = =>
    stats = {
      scoreStats: score.stats,
    }
    console.log(JSON.stringify(stats))
  archive.playLight(onAction, onEnd)
