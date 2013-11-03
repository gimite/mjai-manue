assert = require("assert")
DangerEstimator = require("./danger_estimator")
Pai = require("./pai")
Util = require("./util")

class MockGame

  constructor: (params) ->

    @_tehais = []
    @_prereachSutehais = []
    @_postreachSutehais = []
    @_doras = []
    @_anpais = []
    @_visiblePais = []
    for k, v of params
      this[k] = v

    @_players = [
      {
        id: 0,
        tehais: @_tehais,
        sutehais: [],
      },
      {
        id: 1,
        sutehais: @_prereachSutehais.concat(@_postreachSutehais),
        reachSutehaiIndex: @_prereachSutehais.length - 1,
      },
      {
        id: 2,
        sutehais: [],
      },
      {
        id: 3,
        sutehais: [],
      },
    ]
    for player in @_players
      player.ho = player.sutehais
      player.reachState = "none"
      player.furos = []
  
  jikaze: (player) ->
    return new Pai("t", 1 + player.id)

  anpais: (player) ->
    if player == @_players[1]
      return @_anpais
    else
      throw new Error("not implemented")

  visiblePais: (player) ->
    if player == @_players[0]
      return @_visiblePais
    else
      throw new Error("not implemented")

  yakuhaiFan: (pai, player) ->
    if pai.type() == "t" && pai.number() >= 5
      return 1
    else
      return (if pai.hasSameSymbol(@bakaze()) then 1  else 0) + (if pai.hasSameSymbol(@jikaze(player)) then 1 else 0)

Util.attrReader(MockGame, ["players", "doras", "bakaze"])

getScene = (params) ->
  game = new MockGame(params)
  return new DangerEstimator.Scene(game, game.players()[0], game.players()[1])

scene = getScene({})
assert.ok(scene.tsupai(new Pai("E")))
assert.ok(!scene.tsupai(new Pai("1m")))

scene = getScene(_anpais: Pai.strToPais("4p"))
assert.ok(scene.suji(new Pai("1p")))
assert.ok(scene.weakSuji(new Pai("1p")))
assert.ok(scene.suji(new Pai("7p")))
assert.ok(scene.weakSuji(new Pai("7p")))
assert.ok(!scene.suji(new Pai("2p")))
assert.ok(!scene.weakSuji(new Pai("2p")))
assert.ok(!scene.suji(new Pai("1m")))
assert.ok(!scene.weakSuji(new Pai("1m")))

scene = getScene(_anpais: Pai.strToPais("1p 7p"))
assert.ok(scene.suji(new Pai("4p")))
assert.ok(scene.weakSuji(new Pai("4p")))

scene = getScene(
    _anpais: Pai.strToPais("5p 4p"),
    _prereachSutehais: Pai.strToPais("5p 4p"))
assert.ok(scene.reachSuji(new Pai("1p")))
assert.ok(!scene.reachSuji(new Pai("2p")))

scene = getScene(
    _anpais: Pai.strToPais("1p"),
    _prereachSutehais: Pai.strToPais("1p"))
assert.ok(scene.reachSuji(new Pai("4p")))

scene = getScene(
    _anpais: Pai.strToPais("4p E 4s"),
    _prereachSutehais: Pai.strToPais("4p E"))
assert.ok(scene.prereachSuji(new Pai("1p")))
assert.ok(!scene.prereachSuji(new Pai("1s")))

scene = getScene(
    _anpais: Pai.strToPais("1p"),
    _prereachSutehais: Pai.strToPais("1p"))
assert.deepEqual(
    scene.urasuji(new Pai("p", n)) for n in [1...10], 
    [false, true, false, false, true, false, false, false, false])
assert.ok(!scene.urasuji(new Pai("2m")))

scene = getScene(
    _anpais: Pai.strToPais("5p"),
    _prereachSutehais: Pai.strToPais("5p"))
assert.deepEqual(
    scene.urasuji(new Pai("p", n)) for n in [1...10], 
    [true, false, false, true, false, true, false, false, true])
assert.ok(!scene.urasuji(new Pai("1m")))

scene = getScene(
    _anpais: Pai.strToPais("1p 5p"),
    _prereachSutehais: Pai.strToPais("1p"))
assert.ok(!scene.urasuji(new Pai("2p")))

scene = getScene(
    _anpais: Pai.strToPais("1p E S W 1s"),
    _prereachSutehais: Pai.strToPais("1p E S W 1s"))
assert.ok(scene.earlyUrasuji(new Pai("5p")))
assert.ok(!scene.earlyUrasuji(new Pai("5s")))
assert.ok(scene.reachUrasuji(new Pai("5s")))
assert.ok(!scene.reachUrasuji(new Pai("5p")))

scene = getScene(
    _anpais: Pai.strToPais("1p 6p"),
    _prereachSutehais: Pai.strToPais("1p 6p"))
assert.deepEqual(
    scene.aida4ken(new Pai("p", n)) for n in [1...10], 
    [false, true, false, false, true, false, false, false, false])
assert.ok(!scene.aida4ken(new Pai("2m")))

scene = getScene(
    _anpais: Pai.strToPais("3p"),
    _prereachSutehais: Pai.strToPais("3p"))
assert.deepEqual(
    scene.matagisuji(new Pai("p", n)) for n in [1...10], 
    [true, true, false, true, true, false, false, false, false])
assert.ok(!scene.matagisuji(new Pai("1m")))

scene = getScene(
    _anpais: Pai.strToPais("2p"),
    _prereachSutehais: Pai.strToPais("2p"))
assert.deepEqual(
    scene.matagisuji(new Pai("p", n)) for n in [1...10], 
    [true, false, false, true, false, false, false, false, false])

scene = getScene(
    _anpais: Pai.strToPais("3p 4p"),
    _prereachSutehais: Pai.strToPais("3p"))
assert.ok(!scene.matagisuji(new Pai("1p")))

scene = getScene(
    _anpais: Pai.strToPais("3p E S 7p W"),
    _prereachSutehais: Pai.strToPais("3p E S 7p W"))
assert.ok(scene.lateMatagisuji(new Pai("9p")))
assert.ok(!scene.earlyMatagisuji(new Pai("9p")))
assert.ok(scene.earlyMatagisuji(new Pai("1p")))
assert.ok(!scene.lateMatagisuji(new Pai("1p")))

scene = getScene(
    _anpais: Pai.strToPais("3p E S 7p"),
    _prereachSutehais: Pai.strToPais("3p E S 7p"))
assert.ok(scene.reachMatagisuji(new Pai("9p")))
assert.ok(!scene.reachMatagisuji(new Pai("1p")))

scene = getScene(
    _anpais: Pai.strToPais("1p"),
    _prereachSutehais: Pai.strToPais("1p"))
assert.deepEqual(
    scene.senkisuji(new Pai("p", n)) for n in [1...10], 
    [false, false, true, false, false, true, false, false, false])
assert.ok(!scene.senkisuji(new Pai("3m")))

# Doesn't count the pai which I'm going to discard.
scene = getScene(
    _visiblePais: Pai.strToPais("1p 1p"))
assert.ok(scene["visible>=1"](new Pai("1p")))
assert.ok(!scene["visible>=2"](new Pai("1p")))

scene = getScene(
    _visiblePais: Pai.strToPais("1p 1p 1p"))
assert.ok(scene["visible>=2"](new Pai("1p")))
assert.ok(!scene["visible>=3"](new Pai("1p")))

scene = getScene(
    _visiblePais: Pai.strToPais("4p"))
assert.ok(scene["sujiVisible<=1"](new Pai("1p")))
assert.ok(!scene["sujiVisible<=0"](new Pai("1p")))

scene = getScene(
    _visiblePais: Pai.strToPais("4p 4p"))
assert.ok(scene["sujiVisible<=2"](new Pai("1p")))
assert.ok(!scene["sujiVisible<=1"](new Pai("1p")))

# TODO Add test for rest of features.
