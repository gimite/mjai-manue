assert = require("assert")
ManueAI = require("./manue_ai")
Game = require("./game")
Pai = require("./pai")
Furo = require("./furo")
Action = require("./action")

strToPids = (str) ->
  return (pai.id() for pai in Pai.strToPais(str))

hasYaku = (goal, yakuName, fan) ->
  for yaku in goal.yakus
    if yaku[0] == yakuName && yaku[1] == fan
      return true
  return false

game = new Game()
state = Game.getDefaultStateForTest()
me = state.players[1]
game.setState(state)
ai = new ManueAI()
ai.initialize(game, me)

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
