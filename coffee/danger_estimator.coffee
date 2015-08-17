fs = require("fs")
Pai = require("./pai")
PaiSet = require("./pai_set")
Util = require("./util")

class Scene

  constructor: (@_game, @_me, @_target) ->
    @_tehaiSet = new PaiSet(@_me.tehais)
    @_anpaiSet = new PaiSet(@_game.anpais(@_target))
    @_visibleSet = new PaiSet(@_game.visiblePais(@_me))
    @_doraSet = new PaiSet(@_game.doras())
    @_bakaze = @_game.bakaze()
    @_targetKaze = @_game.jikaze(@_target)

    prereachSutehais = @_target.sutehais[0...(@_target.reachSutehaiIndex + 1)]
    @_prereachSutehaiSet = new PaiSet(prereachSutehais)
    @_earlySutehaiSet = new PaiSet(prereachSutehais[0...Math.floor(prereachSutehais.length / 2)])
    @_lateSutehaiSet = new PaiSet(
        prereachSutehais[Math.floor(prereachSutehais.length / 2)...prereachSutehais.length])
    reachPai = @_target.sutehais[@_target.reachSutehaiIndex]
    # reachPai may be undefined in unit tests.
    @_reachPaiSet = new PaiSet(if reachPai then [reachPai] else [])

  anpai: (pai) ->
    return @_anpaiSet.has(pai)

  tsupai: (pai) ->
    return pai.type() == "t"

  suji: (pai) ->
    return @_sujiOf(pai, @_anpaiSet)

  weakSuji: (pai) ->
    return @_weakSujiOf(pai, @_anpaiSet)

  reachSuji: (pai) ->
    return @_weakSujiOf(pai, @_reachPaiSet)

  prereachSuji: (pai) ->
    return @_sujiOf(pai, @_prereachSutehaiSet)

  urasuji: (pai) ->
    return @_urasujiOf(pai, @_prereachSutehaiSet)

  earlyUrasuji: (pai) ->
    return @_urasujiOf(pai, @_earlySutehaiSet)

  reachUrasuji: (pai) ->
    return @_urasujiOf(pai, @_reachPaiSet)

  aida4ken: (pai) ->
    if pai.type() == "t"
      return false
    else
      return (pai.number() >= 2 && pai.number() <= 5 &&
            @_prereachSutehaiSet.has(new Pai(pai.type(), pai.number() - 1)) &&
            @_prereachSutehaiSet.has(new Pai(pai.type(), pai.number() + 4))) ||
          (pai.number() >= 5 && pai.number() <= 8 &&
            @_prereachSutehaiSet.has(new Pai(pai.type(), pai.number() - 4)) &&
            @_prereachSutehaiSet.has(new Pai(pai.type(), pai.number() + 1)))

  matagisuji: (pai) ->
    return @_matagisujiOf(pai, @_prereachSutehaiSet)

  earlyMatagisuji: (pai) ->
    return @_matagisujiOf(pai, @_earlySutehaiSet)

  lateMatagisuji: (pai) ->
    return @_matagisujiOf(pai, @_lateSutehaiSet)

  reachMatagisuji: (pai) ->
    return @_matagisujiOf(pai, @_reachPaiSet)

  senkisuji: (pai) ->
    return @_senkisujiOf(pai, @_prereachSutehaiSet)

  earlySenkisuji: (pai) ->
    return @_senkisujiOf(pai, @_earlySutehaiSet)

  outerPrereachSutehai: (pai) ->
    return @_outer(pai, @_prereachSutehaiSet)

  outerEarlySutehai: (pai) ->
    return @_outer(pai, @_earlySutehaiSet)

  dora: (pai) ->
    return @_doraSet.has(pai)

  doraSuji: (pai) ->
    return @_weakSujiOf(pai, @_doraSet)

  doraMatagi: (pai) ->
    return @_matagisujiOf(pai, @_doraSet)

  fanpai: (pai) ->
    return @_fanpaiFansu(pai) >= 1

  ryenfonpai: (pai) ->
    return @_fanpaiFansu(pai) >= 2

  sangenpai: (pai) ->
    return pai.type() == "t" && pai.number() >= 5

  fonpai: (pai) ->
    return pai.type() == "t" && pai.number() < 5

  bakaze: (pai) ->
    return pai.hasSameSymbol(@_bakaze)

  jikaze: (pai) ->
    return pai.hasSameSymbol(@_targetKaze)

  # n can be negative.
  _nOuterPrereachSutehai: (pai, n) ->
    if pai.type() == "t" || pai.number() == 5
      return false
    else
      nInnerNumber = (if pai.number() < 5 then pai.number() + n else pai.number() - n)
      if nInnerNumber >= 1 && nInnerNumber <= 9 &&
          ((pai.number() < 5 && nInnerNumber <= 5) || (pai.number() > 5 && nInnerNumber >= 5))
        return @_prereachSutehaiSet.has(new Pai(pai.type(), nInnerNumber))
      else
        return false

  _nOrMoreOfNeighborsInPrereachSutehais: (pai, n, neighborDistance) ->
    if pai.type() == "t"
      return false
    else
      numNeighbors =
          Util.count [(pai.number() - neighborDistance)...(pai.number() + neighborDistance + 1)], (n) =>
            n >= 1 && n <= 9 && @_prereachSutehaiSet.count(new Pai(pai.type(), n))
      return numNeighbors >= n

  _sujiOf: (pai, targetPaiSet) ->
    if pai.type() == "t"
      return false
    else
      return Util.all @_getSujiNumbers(pai), (n) =>
        targetPaiSet.has(new Pai(pai.type(), n))

  _weakSujiOf: (pai, targetPaiSet) ->
    if pai.type() == "t"
      return false
    else
      return Util.any @_getSujiNumbers(pai), (n) =>
        targetPaiSet.has(new Pai(pai.type(), n))

  _getSujiNumbers: (pai) ->
    return (n for n in [pai.number() - 3, pai.number() + 3] when n >= 1 && n <= 9)

  # Returns sujis which contain the given pai and is alive i.e. none of pais in the suji are anpai.
  # Uses the first pai to represent the suji. e.g. 1p for 14p suji
  _getPossibleSujis: (pai) ->
    if pai.type() == "t"
      return []
    else
      sujis = []
      for n in [pai.number() - 3, pai.number()]
        if Util.all [n, n + 3], ((m) => m >= 1 && m <= 9 && !@_anpaiSet.has(new Pai(pai.type(), m)))
          sujis.push(new Pai(pai.type(), n))
      return sujis

  _nChanceOrLess: (pai, n) ->
    if pai.type() == "t" || (pai.number() >= 4 && pai.number() <= 6)
      return false
    else
      return Util.any [1...3], (i) =>
        kabePai = new Pai(pai.type(), pai.number() + (if pai.number() < 5 then i else -i))
        @_visibleSet.count(kabePai) >= 4 - n

  _numNOrInner: (pai, n) ->
    return pai.type() != "t" && pai.number() >= n && pai.number() <= 10 - n

  _visibleNOrMore: (pai, n) ->
    return @_visibleSet.count(pai) >= n

  _urasujiOf: (pai, targetPaiSet) ->
    sujis = @_getPossibleSujis(pai)
    return Util.any sujis, (s) =>
      (s.next(-1) && targetPaiSet.has(s.next(-1))) || (s.next(4) && targetPaiSet.has(s.next(4)))

  _senkisujiOf: (pai, targetPaiSet) ->
    sujis = @_getPossibleSujis(pai)
    return Util.any sujis, (s) =>
      (s.next(-2) && targetPaiSet.has(s.next(-2))) || (s.next(5) && targetPaiSet.has(s.next(5)))

  _matagisujiOf: (pai, targetPaiSet) ->
    sujis = @_getPossibleSujis(pai)
    return Util.any sujis, (s) =>
      (s.next(1) && targetPaiSet.has(s.next(1))) || (s.next(2) && targetPaiSet.has(s.next(2)))

  _outer: (pai, targetPaiSet) ->
    if pai.type() == "t" || pai.number() == 5
      return false
    else
      innerNumbers = (if pai.number() < 5 then [(pai.number() + 1)...6] else [5...pai.number()])
      return Util.any innerNumbers, (n) =>
        targetPaiSet.has(new Pai(pai.type(), n))

  _fanpaiFansu: (pai) ->
    return @_game().yakuhaiFan(pai, @_target)

[0...4].forEach (i) ->
  Scene.prototype["chances<=#{i}"] = (pai) ->
    return @_nChanceOrLess(pai, i)

[1...4].forEach (i) ->
  Scene.prototype["visible>=#{i}"] = (pai) ->
    return @_visibleNOrMore(pai, i + 1)

[0...4].forEach (i) ->
  Scene.prototype["sujiVisible<=#{i}"] = (pai) ->
    if pai.type() == "t"
      return false
    else
      return Util.any @_getSujiNumbers(pai), (n) =>
        !@_visibleNOrMore(new Pai(pai.type(), n), i + 1)

[2...6].forEach (i) ->
  Scene.prototype["#{i}<=n<=#{10 - i}"] = (pai) ->
    return @_numNOrInner(pai, i)

[2...5].forEach (i) ->
  Scene.prototype["inTehais>=#{i}"] = (pai) ->
    return @_tehaiSet.count(pai) >= i

[1...5].forEach (i) ->
  Scene.prototype["sujiInTehais>=#{i}"] = (pai) ->
    if pai.type() == "t"
      return false
    else
      return Util.any @_getSujiNumbers(pai), (n) =>
        @_tehaiSet.count(new Pai(pai.type(), n)) >= i

[1...3].forEach (i) ->
  [1...(i * 2 + 1)].forEach (j) ->
    Scene.prototype["+-#{i}InPrereachSutehais>=#{j}"] = (pai) ->
      return @_nOrMoreOfNeighborsInPrereachSutehais(pai, j, i)

[1...3].forEach (i) ->
  Scene.prototype["#{i}OuterPrereachSutehai"] = (pai) ->
    return @_nOuterPrereachSutehai(pai, i)

[1...3].forEach (i) ->
  Scene.prototype["#{i}InnerPrereachSutehai"] = (pai) ->
    return @_nOuterPrereachSutehai(pai, -i)

[1...9].forEach (i) ->
  Scene.prototype["sameTypeInPrereach>=#{i}"] = (pai) ->
    if pai.type() == "t"
      return false
    else
      numSameType = Util.count [1...10], (n) =>
        @_prereachSutehaiSet.has(new Pai(pai.type(), n))
      return numSameType + 1 >= i

class DangerEstimator

  constructor: (baseDir) ->
    @_root = JSON.parse(fs.readFileSync("#{baseDir}/share/danger_tree.all.json").toString("utf-8"))

  getScene: (game, me, target) ->
    return new Scene(game, me, target)

  estimateProb: (scene, pai) ->
    pai = pai.removeRed()
    node = @_root
    features = []
    while node.feature_name
      value = scene[Util.camelCase(node.feature_name)](pai)
      features.push({name: node.feature_name, value: value})
      if value
        node = node.positive
      else
        node = node.negative
    return {prob: node.average_prob, features: features}

DangerEstimator.Scene = Scene

module.exports = DangerEstimator
