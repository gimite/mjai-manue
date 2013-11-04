assert = require("assert")
Game = require("./game")
Pai = require("./pai")
Action = require("./action")
Util = require("./util")

getDefaultState = ->
  players = []
  for i in [0...4]
    players.push({
      id: i,
      tehais: (Pai.UNKNOWN for _ in [0...13])
      furos: [],
      ho: [],
      sutehais: [],
      extraAnpais: [],
      reachState: "none",
      reachHoIndex: null,
      reachSutehaiIndex: null,
    })
  players[0].reachState = "accepted"
  players[0].reachHoIndex = players[0].reachSutehaiIndex = 0
  players[1].tehais = (Pai.UNKNOWN for _ in [0...14])
  return {
    players: players,
    bakaze: new Pai("E"),
    kyokuNum: 1,
    honba: 0,
    oya: players[0],
    chicha: players[0],
    doraMarkers: [],
    numPipais: Pai.NUM_IDS * 4 - 13 * 4 - 14,
  }

game = new Game()
state = getDefaultState()
state.players[0].tehais = Pai.strToPais("1m 2m 3m 4m 5m 6m 7m 8m 9m 3p 4p S S")
state.players[0].ho = state.players[0].sutehais = Pai.strToPais("1p")
game.setState(state)
game.updateState(new Action(type: "dahai", actor: state.players[1], pai: new Pai("2p"), tsumogiri: false))
assert.ok(!game.isFuriten(state.players[0]))
assert.ok(game.canHora(state.players[0]))

game = new Game()
state = getDefaultState()
state.players[0].tehais = Pai.strToPais("1m 2m 3m 4m 5m 6m 7m 8m 9m 3p 4p S S")
state.players[0].ho = state.players[0].sutehais = Pai.strToPais("2p")
game.setState(state)
game.updateState(new Action(type: "dahai", actor: state.players[1], pai: new Pai("2p"), tsumogiri: false))
assert.ok(game.isFuriten(state.players[0]))
assert.ok(!game.canHora(state.players[0]))
