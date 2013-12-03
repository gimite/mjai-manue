fs = require("fs")
printf = require("printf")
seedRandom = require("seed-random")
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
          possibleActions = @categorizeActions(action.possibleActions)
          if possibleActions.hora
            return @createAction(possibleActions.hora)
          else if action.type == "tsumo" && @player().reachState == "accepted"
            return @createAction(type: "dahai", pai: action.pai, tsumogiri: true)
          else
            decision = @decideDahai(
                action.cannotDahai || [],
                @player().reachState == "declared",
                possibleActions.reach)
            if decision.reach
              return @createAction(possibleActions.reach)
            else
              return @createAction(
                  type: "dahai",
                  pai: decision.dahai,
                  tsumogiri:
                      action.type in ["tsumo", "reach"] &&
                          decision.dahai.equal(@player().tehais[@player().tehais.length - 1]))
    
    else

      switch action.type
        when "dahai", "kakan"
          possibleActions = @categorizeActions(action.possibleActions)
          if possibleActions.hora
            return @createAction(possibleActions.hora)
          else if possibleActions.furos.length > 0
            return @decideFuro(possibleActions.furos)

    return @createAction(type: "none")

  decideDahai: (forbiddenDahais, reachDeclared, canReach) ->

    candDahais = []
    for pai in @player().tehais
      if (Util.all candDahais, ((p) -> !p.equal(pai))) &&
          (Util.all forbiddenDahais, ((p) -> !p.equal(pai)))
        candDahais.push(pai)

    metrics = {}
    if canReach
      nowMetrics = @getMetrics(@player().tehais, @player().furos, candDahais, "now")
      nowMetrics = @selectTenpaiMetrics(nowMetrics)
      @mergeMetrics(metrics, 0, nowMetrics)
      neverMetrics = @getMetrics(@player().tehais, @player().furos, candDahais, "never")
      @mergeMetrics(metrics, -1, neverMetrics)
    else
      defaultMetrics = @getMetrics(
          @player().tehais, @player().furos, candDahais, if reachDeclared then "now" else "default")
      if reachDeclared
        defaultMetrics = @selectTenpaiMetrics(defaultMetrics)
      @mergeMetrics(metrics, -1, defaultMetrics)

    @printMetrics(metrics)
    @printTenpaiProbs()
    key = @chooseBestMetric(metrics, true)
    console.log("decidedKey", key)
    [actionIdx, paiStr] = key.split(/\./)
    return {
      dahai: new Pai(paiStr),
      shanten: metrics[key].shanten,
      reach: parseInt(actionIdx) == 0,
    }

  mergeMetrics: (metrics, prefix, otherMetrics) ->
    for key, metric of otherMetrics
      metrics["#{prefix}.#{key}"] = metric

  selectTenpaiMetrics: (metrics) ->
    result = {}
    for key, metric of metrics
      if metric.shanten <= 0
        result[key] = metric
    return result

  decideFuro: (furoActions) ->

    metrics = {}

    noneMetrics = @getMetrics(@player().tehais, @player().furos, [null], "default")
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
      furoMetrics = @getMetrics(tehais, furos, candDahais, "default")
      @mergeMetrics(metrics, j, furoMetrics)

    @printMetrics(metrics)
    @printTenpaiProbs()
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

  getMetrics: (tehais, furos, candDahais, reachMode) ->

    analysis = new ShantenAnalysis(
        pai.id() for pai in tehais,
        {allowedExtraPais: 1})

    safeProbs = @getSafeProbs(candDahais, analysis)
    metrics = @getHoraEstimation(candDahais, analysis, tehais, furos, reachMode)

    tenpaiRyukyokuAveragePoints = @getRyukyokuAveragePoints(true)
    notenRyukyokuAveragePoints = @getRyukyokuAveragePoints(false)
    ryukyokuProb = @getRyukyokuProb()

    for pai in candDahais
      key = (if pai then pai.toString() else "none")
      metric = metrics[key]
      metric.safeProb = safeProbs[key]
      metric.safeExpectedPoints = metric.safeProb * metric.expectedHoraPoints
      metric.unsafeExpectedPoints = -(1 - metric.safeProb) * @_stats.averageHoraPoints
      metric.ryukyokuProb = ryukyokuProb
      if metric.shanten <= 0
        metric.ryukyokuAveragePoints = tenpaiRyukyokuAveragePoints
      else
        metric.ryukyokuAveragePoints = notenRyukyokuAveragePoints
      metric.ryukyokuExpectedPoints = metric.safeProb * ryukyokuProb * metric.ryukyokuAveragePoints
      metric.expectedPoints =
          metric.safeExpectedPoints + metric.unsafeExpectedPoints + metric.ryukyokuExpectedPoints
    return metrics

  getRyukyokuAveragePoints: (selfTenpai) ->

    notenRyukyokuTenpaiProb = @getNotenRyukyokuTenpaiProb()
    ryukyokuTenpaiProbs = for i in [0...4]
      player = @game().players()[i]
      if player == @player()
        currentTenpaiProb = (if selfTenpai then 1 else 0)
      else
        currentTenpaiProb = @getTenpaiProb(player)
      currentTenpaiProb * 1 + (1 - currentTenpaiProb) * notenRyukyokuTenpaiProb

    result = 0
    for i in [0...Math.pow(2, 4)]
      tenpais = ((i & Math.pow(2, j)) != 0 for j in [0...4])
      prob = 1
      numTenpais = 0
      for j in [0...4]
        prob *= (if tenpais[j] then ryukyokuTenpaiProbs[j] else 1 - ryukyokuTenpaiProbs[j])
        if tenpais[j]
          ++numTenpais
      if prob > 0
        if tenpais[@player().id]
          points = (if numTenpais == 4 then 0 else 3000 / numTenpais)
        else
          points = (if numTenpais == 0 then 0 else -3000 / (4 - numTenpais))
        result += prob * points
    return result

  # Probability that the player is tenpai at the end of the kyoku if the player is currently
  # noten and the kyoku ends with ryukyoku.
  getNotenRyukyokuTenpaiProb: ->
    notenFreq = @_stats.ryukyokuTenpaiStat.noten
    tenpaiFreq = 0
    t = @game().turn() + 1 / 4
    while t <= Game.FINAL_TURN
      tenpaiFreq += @_stats.ryukyokuTenpaiStat.tenpaiTurnDistribution[t]
      t += 1 / 4
    return tenpaiFreq / (tenpaiFreq + notenFreq)

  chooseBestMetric: (metrics, preferBlack) ->
    maxExpectedPoints = -1 / 0
    bestKey = null
    for key, metric of metrics
      if metric.expectedPoints > maxExpectedPoints ||
          (metric.expectedPoints == maxExpectedPoints && preferBlack && key + "r" == bestKey)
        maxExpectedPoints = metric.expectedPoints
        bestKey = key
    return bestKey

  printMetrics: (metrics) ->
    sortedMetrics = ([k, m] for k, m of metrics)
    sortedMetrics.sort(([k1, m1], [k2, m2]) -> m2.expectedPoints - m1.expectedPoints)
    if sortedMetrics.length == 0
      return
    @log(
        "| action | expPt | unsafeProb | horaProb | avgHoraPt | safeExpPt | unsafeExpPt " +
        "| ryukyokuProb | ryukyokuAvgPt |  shanten |")
    for [key, metric] in sortedMetrics
      @log(printf(
          "| %-6s | %5d |      %.3f |    %.3f | %9d | %9d | %11d |        %.3f | %13d | %8O |",
          key, 
          metric.expectedPoints, 
          1 - metric.safeProb, 
          metric.horaProb, 
          metric.averageHoraPoints, 
          metric.safeExpectedPoints, 
          metric.unsafeExpectedPoints,
          metric.ryukyokuProb,
          metric.ryukyokuAveragePoints,
          metric.shanten))
    @log("")

  getSafeProbs: (candDahais, analysis) ->
    safeProbs = {}
    for pai in candDahais
      key = (if pai then pai.toString() else "none")
      safeProbs[key] = 1
    for player in @game().players()
      if player != @player()
        scene = @_dangerEstimator.getScene(@game(), @player(), player)
        tenpaiProb = @getTenpaiProb(player)
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
              safeProb = 1 - tenpaiProb * probInfo.prob
            safeProbs[pai.toString()] *= safeProb
            probInfos[pai.toString()] = probInfo
          else
            safeProbs["none"] = 1
        console.log("danger")
        console.log(probInfos)
    return safeProbs

  getTenpaiProb: (player) ->
    if player.reachState != "none"
      return 1
    else
      numRemainTurns = Math.floor(@game().numPipais() / 4)
      numFuros = player.furos.length
      stat = @_stats.yamitenStats["#{numRemainTurns},#{numFuros}"]
      if stat
        return stat.tenpai / stat.total
      else
        return 1

  printTenpaiProbs: ->
    output = ""
    for player in @game().players()
      if player != @player()
        output += printf("%d: %.3f  ", player.id, @getTenpaiProb(player))
    @log("tenpaiProbs:  " + output)

  getHoraEstimation: (candDahais, analysis, tehais, furos, reachMode) ->

    currentVector = new PaiSet(tehais).array()
    goals = []
    for goal in analysis.goals()
      if reachMode == "now" && goal.shanten > 0
        continue
      if analysis.shanten() > 3 && goal.shanten > analysis.shanten()
        # If shanten > 3, including goals with extra pais is too slow.
        continue
      goal.requiredBitVectors = @countVectorToBitVectors(goal.requiredVector)
      goal.furos = furos
      @calculateFan(goal, tehais, reachMode)
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
    numTries = 1000
    # Uses a fixed seed to get a reproducable result, and to make the result comparable
    # e.g., with and without reach.
    random = seedRandom("")
    totalHoraVector = (0 for _ in [0...(Pai.NUM_IDS + 1)])
    totalPointsVector = (0 for _ in [0...(Pai.NUM_IDS + 1)])
    totalYakuToFanVector = ({} for _ in [0...(Pai.NUM_IDS + 1)])
    for i in [0...numTries]
      Util.shuffle(invisiblePids, random, numTsumos)
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

    shantenVector = (Infinity for _ in [0...(Pai.NUM_IDS + 1)])
    shantenVector[Pai.NUM_IDS] = analysis.shanten()
    for goal in analysis.goals()
      for pid in [0...Pai.NUM_IDS]
        if goal.throwableVector[pid] > 0 && goal.shanten < shantenVector[pid]
          shantenVector[pid] = goal.shanten

    metrics = {}
    for pai in candDahais
      pid = (if pai then pai.id() else Pai.NUM_IDS)
      key = (if pai then pai.toString() else "none")
      metrics[key] = {
        horaProb: totalHoraVector[pid] / numTries,
        averageHoraPoints: totalPointsVector[pid] / totalHoraVector[pid],
        expectedHoraPoints: totalPointsVector[pid] / numTries,
        shanten: shantenVector[pid],
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

  countVectorToStr: (countVector) ->
    return new PaiSet({array: countVector}).toString()

  countVectorToBitVectors: (countVector) ->
    bitVectors = []
    for i in [1...5]
      bitVectors.push(new BitVector(c >= i for c in countVector))
    return bitVectors

  calculateFan: (goal, tehais, reachMode) ->

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

    if reachMode != "never"
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

  getRyukyokuProb: ->
    currentTurn = Math.floor((Game.NUM_INITIAL_PIPAIS - @game().numPipais()) / 4)
    den = 0
    for i in [currentTurn...@_stats.numTurnsDistribution.length]
      den += @_stats.numTurnsDistribution[i]
    return @_stats.ryukyokuRatio / den

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
