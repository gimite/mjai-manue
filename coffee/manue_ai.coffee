fs = require("fs")
printf = require("printf")
AI = require("./ai")
Pai = require("./pai")
PaiSet = require("./pai_set")
ShantenAnalysis = require("./shanten_analysis")
BitVector = require("./bit_vector")
DangerEstimator = require("./danger_estimator")
Game = require("./game")
Furo = require("./furo")
Util = require("./util")

class ManueAI extends AI

  constructor: ->
    @_dangerEstimator = new DangerEstimator()
    @_stats = JSON.parse(fs.readFileSync("../share/game_stats.json").toString("utf-8"))

  respondToAction: (action) ->

    #console.log(action, action.actor, @player, action.type)

    if action.actor == @player()

      switch action.type
        when "tsumo", "chi", "pon", "reach"
          actions = @categorizeActions(action.possibleActions)
          if actions.hora
            return @createAction(actions.hora)
          else if actions.reach && new ShantenAnalysis(pai.id() for pai in @player().tehais).shanten() <= 0
            # Checks tenpai because possibleActions can include reach on chitoitsu/kokushimuso tenpai.
            return @createAction(actions.reach)
          else if @player().reachState == "accepted"
            return @createAction(type: "dahai", pai: action.pai, tsumogiri: true)
          else
            dahai = @decideDahai(action.cannotDahai || [])
            return @createAction(
                type: "dahai",
                pai: dahai,
                tsumogiri: action.type == "tsumo" && dahai.equal(action.pai))
    
    else

      switch action.type
        when "dahai", "kakan"
          actions = @categorizeActions(action.possibleActions)
          if actions.hora
            return @createAction(actions.hora)
          else if actions.furos.length > 0
            return @decideFuro(actions.furos)

    return @createAction(type: "none")

  decideDahai: (forbiddenDahais) ->

    analysis = new ShantenAnalysis(
        pai.id() for pai in @player().tehais,
        {allowedExtraPais: 1})

    candDahais = []
    for pai in @player().tehais
      if (Util.all candDahais, ((p) -> !p.equal(pai))) &&
          (Util.all forbiddenDahais, ((p) -> !p.equal(pai)))
        candDahais.push(pai)

    metrics = @getMetrics(@player().tehais, @player().furos, candDahais)
    @printMetrics(metrics)
    paiStr = @chooseBestMetric(metrics, true)
    console.log("decidedDahai", paiStr)
    return new Pai(paiStr)

  decideFuro: (furoActions) ->

    metrics = {}

    noneMetrics = @getMetrics(@player().tehais, @player().furos, [null])
    metrics["none"] = noneMetrics["none"]

    for j in [0...furoActions.length]
      action = furoActions[j]
      tehais = @player().tehais.concat([])
      for pai in action.consumed
        for i in [0...tehais.length]
          if tehais[i].equal(pai)
            tehais.splice(i, 1)
            break
      furos = @player().furos.concat([
          new Furo(type: action.type, taken: action.pai, consumed: action.consumed, target: action.target)])
      candDahais = []
      for pai in tehais
        if (Util.all candDahais, ((p) -> !p.equal(pai))) && !@isKuikae(action, pai)
          candDahais.push(pai)
      furoMetrics = @getMetrics(tehais, furos, candDahais)
      for paiStr, metric of furoMetrics
        metrics["#{j}.#{paiStr}"] = metric

    @printMetrics(metrics)
    key = @chooseBestMetric(metrics, false)
    console.log("decidedKey", key)

    if key == "none"
      return @createAction(type: "none")
    else
      [actionIdx, paiStr] = key.split(/\./)
      return @createAction(furoActions[parseInt(actionIdx)])

  isKuikae: (furoAction, dahai) ->
    pais = furoAction.consumed.concat([dahai])
    pais.sort(Pai.compare)
    if pais[1].hasSameSymbol(pais[0]) && pais[2].hasSameSymbol(pais[0])
      return true
    else if pais[1].hasSameSymbol(pais[0].next(1)) &&
        pais[2].hasSameSymbol(pais[0].next(2))
      return true
    else
      return false

  getMetrics: (tehais, furos, candDahais) ->

    analysis = new ShantenAnalysis(
        pai.id() for pai in tehais,
        {allowedExtraPais: 1})
    safeProbs = @getSafeProbs(candDahais, analysis)
    metrics = @getHoraEstimation(candDahais, analysis, tehais, furos)

    for pai in candDahais
      key = (if pai then pai.toString() else "none")
      metric = metrics[key]
      metric.safeProb = safeProbs[key]
      metric.safeExpectedPoints = metric.safeProb * metric.expectedHoraPoints
      metric.unsafeExpectedPoints = -(1 - metric.safeProb) * @_stats.averageHoraPoints
      metric.expectedPoints = metric.safeExpectedPoints + metric.unsafeExpectedPoints
    return metrics

  chooseBestMetric: (metrics, preferBlack) ->
    maxExpectedPoints = -1 / 0
    bestKey = null
    for key, metric of metrics
      if metric.expectedPoints > maxExpectedPoints ||
          (metric.expectedPoints == maxExpectedPoints && preferBlack && @isBlackVersionOf(key, bestKey))
        maxExpectedPoints = metric.expectedPoints
        bestKey = key
    return bestKey

  isBlackVersionOf: (paiStr1, paiStr2) ->
    pai1 = new Pai(paiStr1)
    pai2 = new Pai(paiStr2)
    return pai1.hasSameSymbol(pai2) && !pai1.red() && pai2.red()

  printMetrics: (metrics) ->
    sortedMetrics = ([k, m] for k, m of metrics)
    sortedMetrics.sort(([k1, m1], [k2, m2]) -> m2.expectedPoints - m1.expectedPoints)
    if sortedMetrics.length == 0
      return
    @log("| action | expPt | unsafeProb | horaProb | avgHoraPt | safeExpPt | unsafeExpPt |")
    for [key, metric] in sortedMetrics
      @log(printf(
          "| %-6s | %5d |      %.3f |    %.3f | %9d | %9d | %11d |",
          key, 
          metric.expectedPoints, 
          1 - metric.safeProb, 
          metric.horaProb, 
          metric.averageHoraPoints, 
          metric.safeExpectedPoints, 
          metric.unsafeExpectedPoints))

  getSafeProbs: (candDahais, analysis) ->
    safeProbs = {}
    for pai in candDahais
      key = (if pai then pai.toString() else "none")
      safeProbs[key] = 1
    if analysis.shanten() > 0  # TODO Better handling of tenpai
      for player in @game().players()
        if player != @player() && player.reachState == "accepted"
          scene = @_dangerEstimator.getScene(@game(), @player(), player)
          probInfos = {}
          for pai in candDahais
            if pai
              if scene.anpai(pai)
                probInfo = {anpai: true}
                safeProb = 1
              else
                probInfo = @_dangerEstimator.estimateProb(scene, pai)
                features2 = []
                for feature in probInfo.features
                  features2.push("#{feature.name} #{feature.value}")
                probInfo.features = features2
                safeProb = 1 - probInfo.prob
              safeProbs[pai.toString()] *= safeProb
              probInfos[pai.toString()] = probInfo
            else
              safeProbs["none"] = 1
          console.log("danger")
          console.log(probInfos)
    return safeProbs

  getHoraEstimation: (candDahais, analysis, tehais, furos) ->

    @log("shanten=" + analysis.shanten())
    currentVector = new PaiSet(tehais).array()
    goals = []
    for goal in analysis.goals()
      # If it's tenpai, tenpai must be kept because it has reached.
      # If shanten > 3, including goals with extra pais is too slow.
      if (analysis.shanten() >= 1 && analysis.shanten() <= 3) ||
          goal.shanten == analysis.shanten()
        goal.requiredBitVectors = @countVectorToBitVectors(goal.requiredVector)
        goal.furos = furos
        @calculateFan(goal, tehais)
        if goal.points > 0
          goals.push(goal)
    console.log("goals", goals.length)
    #console.log("requiredBitVectors", new Date() - @_start)

    # for goal in goals
    #   console.log("goalVector", @countVectorToStr(goal.countVector))
    #   console.log({fu: goal.fu, fan: goal.fan, points: goal.points, yakus: goal.yakus})
      # console.log("goalRequiredVector", countVectorToStr(goal.requiredVector))
      # console.log("goalThrowableVector", countVectorToStr(goal.throwableVector))
      # console.log("goalMentsus", ([m.type, new Pai(m.firstPid).toString()] for m in goal.mentsus))

    visiblePaiSet = new PaiSet(@game().visiblePais(@player()))
    invisiblePaiSet = PaiSet.getAll()
    invisiblePaiSet.removePaiSet(visiblePaiSet)
    invisiblePids = (pai.id() for pai in invisiblePaiSet.toPais())
    #console.log("  visiblePaiSet", visiblePaiSet.toString())
    #console.log("invisiblePids", Pai.paisToStr(new Pai(pid) for pid in invisiblePids))

    numTsumos = @getNumExpectedRemainingTurns()
    console.log("numTsumos", numTsumos)
    numTries = 1000
    totalHoraVector = (0 for _ in [0...(Pai.NUM_IDS + 1)])
    totalPointsVector = (0 for _ in [0...(Pai.NUM_IDS + 1)])
    totalYakuToFanVector = ({} for _ in [0...(Pai.NUM_IDS + 1)])
    for i in [0...numTries]
      @shuffle(invisiblePids, numTsumos)
      tsumoVector = new PaiSet(new Pai(pid) for pid in invisiblePids[0...numTsumos]).array()
      tsumoBitVectors = @countVectorToBitVectors(tsumoVector)
      horaVector = (0 for _ in [0...(Pai.NUM_IDS + 1)])
      pointsVector = (0 for _ in [0...(Pai.NUM_IDS + 1)])
      yakuToFanVector = ({} for _ in [0...(Pai.NUM_IDS + 1)])
      #goalVector = (null for _ in [0...Pai.NUM_IDS])
      for goal in goals
        achieved = true
        for i in [0...tsumoBitVectors.length]
          if !goal.requiredBitVectors[i].isSubsetOf(tsumoBitVectors[i])
            achieved = false
            break
        if achieved
          for pid in [0...(Pai.NUM_IDS + 1)]
            if pid == Pai.NUM_IDS || goal.throwableVector[pid] > 0
              horaVector[pid] = 1
              if goal.points > pointsVector[pid]
                pointsVector[pid] = goal.points
                yakuToFanVector[pid] = {}
                for yaku in goal.yakus
                  [name, fan] = yaku
                  yakuToFanVector[pid][name] = fan
              #goalVector[pid] = goal
      for pid in [0...(Pai.NUM_IDS + 1)]
        if horaVector[pid] == 1
          ++totalHoraVector[pid]
          totalPointsVector[pid] += pointsVector[pid]
          for name, fan of yakuToFanVector[pid]
            if name of totalYakuToFanVector[pid]
              totalYakuToFanVector[pid][name] += fan
            else
              totalYakuToFanVector[pid][name] = fan
    #console.log("monte carlo", new Date() - @_start)

    metrics = {}
    for pai in candDahais
      pid = (if pai then pai.id() else Pai.NUM_IDS)
      key = (if pai then pai.toString() else "none")
      metrics[key] = {
        horaProb: totalHoraVector[pid] / numTries,
        averageHoraPoints: totalPointsVector[pid] / totalHoraVector[pid],
        expectedHoraPoints: totalPointsVector[pid] / numTries,
      }
      # for name, fan of totalYakuToFanVector[pid]
      #   stats[name] = Math.floor(fan / totalHoraVector[pid] * 1000) / 1000
      # console.log("  ", pai.toString(), stats)
    return metrics

    # if maxHoraProbPid != maxExpectedPointsPid
    #   gain =
    #     (((totalPointsVector[maxExpectedPointsPid] / numTries) / (totalPointsVector[maxHoraProbPid] / numTries)) - 1) *
    #         (totalHoraVector[maxHoraProbPid] / numTries)
    #   if gain >= 0.01
    #     for name, fan of totalYakuToFanVector[maxExpectedPointsPid]
    #       testAvgFan = fan / totalHoraVector[maxExpectedPointsPid]
    #       baseAvgFan = (totalYakuToFanVector[maxHoraProbPid][name] || 0) / totalHoraVector[maxHoraProbPid]
    #       if testAvgFan >= baseAvgFan + 0.1
    #         testPaiStr = new Pai(maxExpectedPointsPid).toString()
    #         basePaiStr = new Pai(maxHoraProbPid).toString()
    #         console.log("  choice based on #{name}: #{testPaiStr} (#{testAvgFan}) vs #{basePaiStr} (#{baseAvgFan})")

    # # Just returning new Pai(maxPid) doesn't work because it may be a red pai.
    # for pai in candDahais
    #   if pai.id() == maxExpectedPointsPid
    #     console.log("  decidedDahai", pai.toString())
    #     return pai
    # throw new Error("should not happen")

  shuffle: (array, n = array.length) ->
    for i in [0...n]
      j = i + Math.floor(Math.random() * (array.length - i))
      tmp = array[i]
      array[i] = array[j]
      array[j] = tmp
    return array

  countVectorToStr: (countVector) ->
    return new PaiSet({array: countVector}).toString()

  countVectorToBitVectors: (countVector) ->
    bitVectors = []
    for i in [1...5]
      bitVectors.push(new BitVector(c >= i for c in countVector))
    return bitVectors

  calculateFan: (goal, tehais) ->

    mentsus = []
    for mentsu in goal.mentsus
      mentsus.push({type: mentsu.type, pais: (new Pai(pid) for pid in mentsu.pids)})
    for furo in goal.furos
      mentsus.push({
        type: ManueAI.FURO_TYPE_TO_MENTSU_TYPE[furo.type()],
        pais: furo.pais(),
      })
    allPais = []
    for mentsu in mentsus
      for pai in mentsu.pais
        allPais.push(pai)
    furoPais = []
    for furo in goal.furos
      for pai in furo.pais()
        furoPais.push(pai)

    goal.yakus = []
    goal.fan = 0

    @addYaku(goal, "reach", 1, 0)

    tanyaochu =
        Util.all allPais, (p) ->
          !p.isYaochu()
    if tanyaochu
      @addYaku(goal, "tyc", 1)

    chantaiyao =
        Util.all mentsus, (m) ->
          Util.any m.pais, (p) ->
            p.isYaochu()
    if chantaiyao
      @addYaku(goal, "cty", 2, 1)

    # TODO Consider ryanmen criteria
    pinfu =
        Util.all mentsus, (m) =>
          m.type =="shuntsu" ||
              (m.type == "toitsu" && @game().yakuhaiFan(m.pais[0], @player()) == 0)
    if pinfu
      @addYaku(goal, "pf", 1, 0)

    yakuhaiFan = 0
    for mentsu in mentsus
      if mentsu.type == "kotsu" || mentsu.type == "kantsu"
        yakuhaiFan += @game().yakuhaiFan(mentsu.pais[0], @player())
    @addYaku(goal, "ykh", yakuhaiFan)

    ipeko =
        Util.any mentsus, (m1) ->
          m1.type == "shuntsu" &&
              Util.any mentsus, (m2) ->
                m2 != m1 && m2.type == "shuntsu" && m2.pais[0].hasSameSymbol(m1.pais[0])
    if ipeko
      @addYaku(goal, "ipk", 1, 0)

    sanshokuDojun =
        Util.any mentsus, (m1) ->
          m1.type == "shuntsu" &&
              Util.all ["m", "p", "s"], (t) ->
                Util.any mentsus, (m2) ->
                  m2.type == "shuntsu" &&
                      m2.pais[0].type() == t &&
                      m2.pais[0].number() == m1.pais[0].number()
    if sanshokuDojun
      @addYaku(goal, "ssj", 2, 1)

    ikkiTsukan =
        Util.any ["m", "p", "s"], (t) ->
          Util.all [1, 4, 7], (n) ->
            Util.any mentsus, (m) ->
              m.type == "shuntsu" && m.pais[0].type() == t && m.pais[0].number() == n
    if ikkiTsukan
      @addYaku(goal, "ikt", 2, 1)

    toitoiho =
        Util.all mentsus, (m) ->
            m.type != "shuntsu"
    if toitoiho
      @addYaku(goal, "tth", 2)

    chiniso =
        Util.any ["m", "p", "s"], (t) ->
          Util.all mentsus, (m) ->
            m.pais[0].type() == t
    honiso =
        Util.any ["m", "p", "s"], (t) ->
          Util.all mentsus, (m) ->
            m.pais[0].type() == t || m.pais[0].type() == "t"
    if chiniso
      @addYaku(goal, "cis", 6, 5)
    else if honiso
      @addYaku(goal, "his", 3, 2)

    if goal.fan > 0
      doras = @game().doras()
      numDoras = 0
      for pai in allPais
        for dora in doras
          if pai.hasSameSymbol(dora)
            ++numDoras
      @addYaku(goal, "dr", numDoras)
      numAkadoras = 0
      for pai in tehais.concat(furoPais)
        if pai.red() && (Util.any allPais, ((p) -> p.hasSameSymbol(pai)))
          ++numAkadoras
      @addYaku(goal, "adr", numAkadoras)

    # TODO Calculate fu more accurately
    goal.fu = (if pinfu || goal.furos.length > 0 then 30 else 40)
    goal.points = @getPoints(goal.fu, goal.fan, @player() == @game().oya())

  addYaku: (goal, name, menzenFan, kuiFan = menzenFan) ->
    fan = (if goal.furos.length == 0 then menzenFan else kuiFan)
    if fan > 0
      goal.yakus.push([name, fan])
      goal.fan += fan

  getPoints: (fu, fan, oya) ->

    if fan >= 13
      basePoints = 8000
    else if fan >= 11
      basePoints = 6000
    else if fan >= 8
      basePoints = 4000
    else if fan >= 6
      basePoints = 3000
    else if fan >= 5 || (fan >= 4 && fu >= 40) || (fan >= 3 && fu >= 70)
      basePoints = 2000
    else if fan >= 1
      basePoints = fu * Math.pow(2, fan + 2)
    else
      basePoints = 0

    return Math.ceil(basePoints * (if oya then 6 else 4) / 100) * 100

  getNumExpectedRemainingTurns: ->
    currentTurn = Math.round((Game.NUM_INITIAL_PIPAIS - @game().numPipais()) / 4)
    num = den = 0
    for i in [currentTurn...@_stats.numTurnsDistribution.length]
      prob = @_stats.numTurnsDistribution[i]
      num += prob * (i - currentTurn + 0.5)
      den += prob
    return (if den == 0 then 0 else Math.round(num / den))

  categorizeActions: (actions) ->
    result = {
      hora: null,
      reach: null,
      furos: [],
    }
    for action in actions || []
      if action.type == "hora"
        result.hora = action
      else if action.type == "reach"
        result.reach = action
      else
        result.furos.push(action)
    return result

ManueAI.getAllPids = ->
  allPids = []
  for pid in [0...Pai.NUM_IDS]
    for i in [0...4]
      allPids.push(pid)
  return allPids

ManueAI.ALL_PIDS = ManueAI.getAllPids()
ManueAI.FURO_TYPE_TO_MENTSU_TYPE = {
  chi: "shuntsu",
  pon: "kotsu",
  daiminkan: "kantsu",
  kakan: "kantsu",
  ankan: "kantsu",
}

module.exports = ManueAI
