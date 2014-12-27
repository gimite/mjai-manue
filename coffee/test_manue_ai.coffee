assert = require("assert")
ManueAI = require("./manue_ai")
Game = require("./game")
Pai = require("./pai")
Furo = require("./furo")
Action = require("./action")
Util = require("./util")

strToPids = (str) ->
  return (pai.id() for pai in Pai.strToPais(str))

hasYaku = (goal, yakuName, fan) ->
  for yaku in goal.yakus
    if yaku[0] == yakuName && yaku[1] == fan
      return true
  return false

class MockDangerEstimator

  getScene: (game, me, target) ->
    map = {
      0: {"1m": 0.5, anpai: -> false},
      2: {"1m": 0.5, anpai: -> false},
      3: {"1m": 0, anpai: -> false},
    }
    return map[target.id]

  estimateProb: (scene, pai) ->
    return {
      prob: scene[pai.toString()],
      features: [],
    }

class MockTenpaiProbEstimator

  estimate: (player, game) ->
    return 0.5

game = new Game()
state = Game.getDefaultStateForTest()
me = state.players[1]
game.setState(state)
ai = new ManueAI()
ai.initialize(game, me)
ai.setDangerEstimatorForTest(new MockDangerEstimator())
ai.setTenpaiProbEstimatorForTest(new MockTenpaiProbEstimator())
ai.setStatsForTest({
  koHoraPointsFreqs: {
    total: 2,
    1000: 1,
    3900: 1,
  },
  oyaHoraPointsFreqs: {
    total: 2,
    1500: 1,
    5800: 1,
  }
})

goal = {
  mentsus: [
    {type: "shuntsu", pids: strToPids("2m 3m 4m")},
    {type: "shuntsu", pids: strToPids("6m 7m 8m")},
    {type: "kotsu", pids: strToPids("2p 2p 2p")},
    {type: "kotsu", pids: strToPids("4p 4p 4p")},
    {type: "toitsu", pids: strToPids("6p 6p")},
  ],
  furos: [],
}
ai.calculateFan(goal, [])
assert.ok(hasYaku(goal, "tyc", 1))
assert.equal(goal.fu, 40)
assert.equal(goal.fan, 2)
assert.equal(goal.points, 2600)

goal = {
  mentsus: [
    {type: "shuntsu", pids: strToPids("1m 2m 3m")},
    {type: "shuntsu", pids: strToPids("6m 7m 8m")},
    {type: "kotsu", pids: strToPids("2p 2p 2p")},
    {type: "kotsu", pids: strToPids("4p 4p 4p")},
    {type: "toitsu", pids: strToPids("6p 6p")},
  ],
  furos: [
    new Furo(type: "pon", taken: new Pai("4p"), consumed: Pai.strToPais("4p 4p"), target: state.players[0]),
  ],
}
ai.calculateFan(goal, [])
assert.equal(goal.points, 0)

goal = {
  mentsus: [
    {type: "shuntsu", pids: strToPids("2m 3m 4m")},
    {type: "kotsu", pids: strToPids("2p 2p 2p")},
    {type: "kotsu", pids: strToPids("4p 4p 4p")},
    {type: "toitsu", pids: strToPids("6p 6p")},
  ],
  furos: [
    new Furo(type: "chi", taken: new Pai("5mr"), consumed: Pai.strToPais("6m 7m"), target: state.players[0]),
  ],
}
ai.calculateFan(goal, [])
assert.ok(hasYaku(goal, "adr", 1))

dists = ai.getHojuScoreChangesDists([new Pai("1m")])
#console.log(dists["1m"].toString())
Util.assertAlmostEqual(dists["1m"].dist().get([0, 0, 0, 0]), 0.5625)
Util.assertAlmostEqual(dists["1m"].dist().get([1500, -1500, 0, 0]), 0.125)
Util.assertAlmostEqual(dists["1m"].dist().get([5800, -5800, 0, 0]), 0.125)
Util.assertAlmostEqual(dists["1m"].dist().get([0, -1000, 1000, 0]), 0.09375)
Util.assertAlmostEqual(dists["1m"].dist().get([0, -3900, 3900, 0]), 0.09375)

game = new Game()
state = Game.getDefaultStateForTest()
me = state.players[1]
me.tehais = Pai.strToPais("1m 2m 3m 6m 7m 8m 1p 2p 3p 6p 8p N N W")
state.players[0].sutehais = state.players[0].ho = Pai.strToPais("7p 7p 7p 7p")
game.setState(state)
ai = new ManueAI()
ai.initialize(game, me)
action = new Action(type: "reach", actor: me)
game.updateState(action)
response = ai.respondToAction(action)
assert.equal(response.type, "dahai")
assert.equal(response.pai.toString(), "W")

game = new Game()
state = Game.getDefaultStateForTest()
me = state.players[1]
me.tehais = Pai.strToPais("1m 2m 3m 6m 7m 8m 1p 2p 3p 6p 8p N N W")
state.players[0].sutehais = state.players[0].ho = Pai.strToPais("S 5m 5s")
state.players[1].sutehais = state.players[1].ho = Pai.strToPais("E S")
state.players[2].sutehais = state.players[2].ho = Pai.strToPais("E S")
state.players[3].sutehais = state.players[3].ho = Pai.strToPais("E S")
state.players[0].reachState = "accepted"
game.setState(state)
ai = new ManueAI()
ai.initialize(game, me)
dists = ai.getHojuScoreChangesDists(Pai.strToPais("2m 2p"))
assert.ok(dists["2m"].expected()[1] > dists["2p"].expected()[1])

dist = ai.getRyukyokuScoreChangesDist(true)
Util.assertAlmostEqual(dist.dist().get([1500, 1500, -1500, -1500]), 0.3663)
dist = ai.getRyukyokuScoreChangesDist(false)
Util.assertAlmostEqual(dist.dist().get([1500, 1500, -1500, -1500]), 0.1446)
