class TenpaiProbEstimator

  constructor: (@_stats) ->

  estimate: (player, game) ->
    if player.reachState != "none"
      return 1
    else
      numRemainTurns = Math.floor(game.numPipais() / 4)
      numFuros = player.furos.length
      stat = @_stats.yamitenStats["#{numRemainTurns},#{numFuros}"]
      if stat
        return stat.tenpai / stat.total
      else
        return 1

module.exports = TenpaiProbEstimator
