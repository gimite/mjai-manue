assert = require("assert")
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
ProbDist = require("./prob_dist")
HashMap = require("./hash_map")
TenpaiProbEstimator = require("./tenpai_prob_estimator")
Util = require("./util")

class ManueAI extends AI

  constructor: ->
    @_stats = JSON.parse(fs.readFileSync("../share/game_stats.json").toString("utf-8"))
    @_stats = Util.mergeObjects(
        @_stats, JSON.parse(fs.readFileSync("../share/light_game_stats.json").toString("utf-8")))
    @_dangerEstimator = new DangerEstimator()
    @_tenpaiProbEstimator = new TenpaiProbEstimator(@_stats)
    @_noChanges = (0 for _ in [0...4])

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
    metrics = @getMetrics(forbiddenDahais, reachDeclared, canReach)
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

  getMetrics: (forbiddenDahais, reachDeclared, canReach) ->

    candDahais = []
    for pai in @player().tehais
      if (Util.all candDahais, ((p) -> !p.equal(pai))) &&
          (Util.all forbiddenDahais, ((p) -> !p.equal(pai)))
        candDahais.push(pai)

    metrics = {}
    if canReach
      nowMetrics = @getMetricsInternal(@player().tehais, @player().furos, candDahais, "now")
      nowMetrics = @selectTenpaiMetrics(nowMetrics)
      @mergeMetrics(metrics, 0, nowMetrics)
      neverMetrics = @getMetricsInternal(@player().tehais, @player().furos, candDahais, "never")
      @mergeMetrics(metrics, -1, neverMetrics)
    else
      defaultMetrics = @getMetricsInternal(
          @player().tehais, @player().furos, candDahais, if reachDeclared then "now" else "default")
      if reachDeclared
        defaultMetrics = @selectTenpaiMetrics(defaultMetrics)
      @mergeMetrics(metrics, -1, defaultMetrics)
    return metrics

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

    noneMetrics = @getMetricsInternal(@player().tehais, @player().furos, [null], "default")
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
      furoMetrics = @getMetricsInternal(tehais, furos, candDahais, "default")
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

  # horaProb: P(hora | this dahai doesn't cause hoju)
  # averageHoraPoints: Average hora points assuming I hora
  # horaPointsDist: Distribution of hora points assuming I hora
  # expectedHoraPoints: Expected hora points assuming this dahai doesn't cause hoju
  # shanten: Shanten number
  getMetricsInternal: (tehais, furos, candDahais, reachMode) ->

    analysis = new ShantenAnalysis(
        pai.id() for pai in tehais,
        {allowedExtraPais: 1})

    safeProbs = @getSafeProbs(candDahais, analysis)
    immediateScoreChangesDists = @getImmediateScoreChangesDists(candDahais)
    metrics = @getHoraEstimation(candDahais, analysis, tehais, furos, reachMode)

    tenpaiRyukyokuAveragePoints = @getRyukyokuAveragePoints(true)
    notenRyukyokuAveragePoints = @getRyukyokuAveragePoints(false)
    ryukyokuProb = @getRyukyokuProb()
    ryukyokuProbOnMyNoHora = @getRyukyokuProbOnMyNoHora()

    scoreChangesDistOnRyukyokuIfTenpaiNow = @getScoreChangesDistOnRyukyoku(true)
    scoreChangesDistOnRyukyokuIfNotenNow = @getScoreChangesDistOnRyukyoku(false)
    scoreChangesDistsOnOtherHora =
        (@getRandomHoraScoreChangesDist(p) for p in @game().players() when p != @player())

    for pai in candDahais
      key = (if pai then pai.toString() else "none")
      m = metrics[key]
      m.red = pai && pai.red()
      m.safeProb = safeProbs[key]
      m.hojuProb = 1 - m.safeProb
      m.safeExpectedPoints = m.safeProb * m.expectedHoraPoints
      m.unsafeExpectedPoints = -(1 - m.safeProb) * @_stats.averageHoraPoints
      m.ryukyokuProb = ryukyokuProb
      if m.shanten <= 0
        m.ryukyokuAveragePoints = tenpaiRyukyokuAveragePoints
      else
        m.ryukyokuAveragePoints = notenRyukyokuAveragePoints
      m.ryukyokuExpectedPoints = m.safeProb * ryukyokuProb * m.ryukyokuAveragePoints
      
      m.immediateScoreChangesDist = immediateScoreChangesDists[key]
      if m.shanten <= 0
        m.scoreChangesDistOnRyukyoku = scoreChangesDistOnRyukyokuIfTenpaiNow
      else
        m.scoreChangesDistOnRyukyoku = scoreChangesDistOnRyukyokuIfNotenNow
      m.scoreChangesDistOnHora = @getScoreChangesDistOnHora(m)

      m.ryukyokuProb = (1 - m.horaProb) * ryukyokuProbOnMyNoHora
      m.othersHoraProb = (1 - m.horaProb) * (1 - ryukyokuProbOnMyNoHora)

      myHoraItem = [m.scoreChangesDistOnHora, m.horaProb]
      ryukyokuItem = [m.scoreChangesDistOnRyukyoku, m.ryukyokuProb]
      otherHoraItems = ([d, m.othersHoraProb / 3] for d in scoreChangesDistsOnOtherHora)
      # console.log("key = ", key)
      # console.log("myHoraItem = ", myHoraItem)
      # console.log("ryukyokuItem = ", ryukyokuItem)
      # console.log("otherHoraItems = ", otherHoraItems)

      m.futureScoreChangesDist = ProbDist.merge([myHoraItem, ryukyokuItem].concat(otherHoraItems))
      m.scoreChangesDist = m.immediateScoreChangesDist.replace(@_noChanges, m.futureScoreChangesDist)
      m.expectedPoints = m.scoreChangesDist.expected()[@player().id]
      m.averageRank = @getAverageRank(m.scoreChangesDist)

    return metrics

  getScoreChangesDistOnHora: (metric) ->
    tsumoHoraProb = @_stats.numTsumoHoras / @_stats.numHoras
    unitDistMap = new HashMap()
    for target in @game().players()
      if target != @player()
        changes = (0 for _ in [0...4])
        changes[@player().id] = 1
        changes[target.id] = -1
      else if @player() == @game().oya()
        changes = (-1/3 for _ in [0...4])
        changes[@player().id] = 1
      else
        changes = (-1/4 for _ in [0...4])
        changes[@player().id] = 1
        changes[@game().oya().id] = -1/2
      prob = (if target == @player() then tsumoHoraProb else (1 - tsumoHoraProb) / 3)
      unitDistMap.set(changes, prob)
    return ProbDist.mult(metric.horaPointsDist, new ProbDist(unitDistMap))

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

  # Distribution of score changes assuming the kyoku ends with ryukyoku.
  getScoreChangesDistOnRyukyoku: (selfTenpai) ->
    notenRyukyokuTenpaiProb = @getNotenRyukyokuTenpaiProb()
    tenpaisDist = new ProbDist([0, 0, 0, 0])
    for player in @game().players()
      if player == @player()
        currentTenpaiProb = (if selfTenpai then 1 else 0)
      else
        currentTenpaiProb = @getTenpaiProb(player)
      ryukyokuTenpaiProb = currentTenpaiProb * 1 + (1 - currentTenpaiProb) * notenRyukyokuTenpaiProb
      tenpais = ((if p == player then 1 else 0) for p in @game().players())
      dist = new ProbDist(new HashMap([
          [[0, 0, 0, 0], 1 - ryukyokuTenpaiProb],
          [tenpais, ryukyokuTenpaiProb]]))
      tenpaisDist = ProbDist.add(tenpaisDist, dist)
    return tenpaisDist.mapValue(this.tenpaisToRyukyokuPoints)

  tenpaisToRyukyokuPoints: (tenpais) ->
    numTenpais = Util.count(tenpais, (t) => t)
    if numTenpais == 0 || numTenpais == 4
      return [0, 0, 0, 0]
    else
      return (
        for tenpai in tenpais
          if tenpai then 3000 / numTenpais else -3000 / (4 - numTenpais)
      )

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
    bestKey = null
    bestMetric = null
    for key, metric of metrics
      if !bestKey || @compareMetric(metric, bestMetric, preferBlack) < 0
        bestKey = key
        bestMetric = metric
    return bestKey

  compareMetric: (lhs, rhs, preferBlack) ->
    if lhs.averageRank < rhs.averageRank
      return -1
    if lhs.averageRank > rhs.averageRank
      return 1
    if lhs.expectedPoints > rhs.expectedPoints
      return -1
    if lhs.expectedPoints < rhs.expectedPoints
      return 1
    if preferBlack
      if !lhs.red && rhs.red
        return -1
      if lhs.red && !rhs.red
        return 1
    return 0

  printMetrics: (metrics) ->
    sortedMetrics = ([k, m] for k, m of metrics)
    sortedMetrics.sort(([k1, m1], [k2, m2]) => @compareMetric(m1, m2, true))
    if sortedMetrics.length == 0
      return
    columns = [
      ["action", "key", "%s"],
      ["avgRank", "averageRank", "%.4f"],
      ["expPt", "expectedPoints", "%d"],
      ["hojuProb", "hojuProb", "%.3f"],
      ["myHoraProb", "horaProb", "%.3f"],
      ["ryukyokuProb", "ryukyokuProb", "%.3f"],
      ["otherHoraProb", "othersHoraProb", "%.3f"],
      ["avgHoraPt", "averageHoraPoints", "%d"],
      ["ryukyokuAvgPt", "ryukyokuAveragePoints", "%d"],
      ["shanten", "shanten", "%d"],
    ]
    @log(Util.formatObjectsAsTable(Util.mergeObjects(m, {key: k}) for [k, m] in sortedMetrics, columns))
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
        # console.log("danger")
        # console.log(probInfos)
    return safeProbs

  # Distribution of score changes which happen immediately, for each possible dahai.
  # i.e., If this dahai causes hoju, score changes due to the hoju. Otherwise [0, 0, 0, 0].
  getImmediateScoreChangesDists: (candDahais) ->
    scoreChangesDists = {}
    for pai in candDahais
      key = (if pai then pai.toString() else "none")
      scoreChangesDists[key] = new ProbDist(@_noChanges)
    for horaPlayer in @game().players()
      if horaPlayer != @player()
        scene = @_dangerEstimator.getScene(@game(), @player(), horaPlayer)
        tenpaiProb = @_tenpaiProbEstimator.estimate(horaPlayer, @game())
        probInfos = {}
        horaPointsFreqs = (
            if horaPlayer == @game().oya() then @_stats.oyaHoraPointsFreqs else @_stats.koHoraPointsFreqs)
        items = []
        for points, freq of horaPointsFreqs
          if points == "total" then continue
          items.push([parseInt(points), freq / horaPointsFreqs.total])
        horaPointsDist = new ProbDist(new HashMap(items))
        hojuChanges = (0 for _ in [0...4])
        hojuChanges[horaPlayer.id] = 1
        hojuChanges[@player().id] = -1
        for pai in candDahais
          key = (if pai then pai.toString() else "none")
          if pai
            if scene.anpai(pai)
              probInfo = {anpai: true}
              hojuProb = 0
            else
              probInfo = @_dangerEstimator.estimateProb(scene, pai)
              features2 = []
              for feature in probInfo.features
                features2.push("#{feature.name} #{feature.value}")
              probInfo.features = features2
              hojuProb = tenpaiProb * probInfo.prob
            unitDist = new ProbDist(new HashMap([[hojuChanges, hojuProb], [@_noChanges, 1 - hojuProb]]))
            # Considers only the first ron for double/triple ron to avoid too many combinations.
            scoreChangesDists[key] = scoreChangesDists[key].replace(
                @_noChanges,
                ProbDist.mult(horaPointsDist, unitDist))
            probInfos[key] = probInfo
    return scoreChangesDists

  getRyukyokuProbOnMyNoHora: ->
    return Math.pow(@getRyukyokuProb(), 3 / 4)

  getRandomHoraScoreChangesDist: (actor) ->

    horaPointsFreqs = (
        if actor == @game().oya() then @_stats.oyaHoraPointsFreqs else @_stats.koHoraPointsFreqs)
    items = []
    for points, freq of horaPointsFreqs
      if points == "total" then continue
      items.push([parseInt(points), freq / horaPointsFreqs.total])
    horaPointsDist = new ProbDist(new HashMap(items))

    return ProbDist.mult(horaPointsDist, @getHoraFactorsDist(actor))

  getHoraFactorsDist: (actor) ->
    tsumoHoraProb = @_stats.numTsumoHoras / @_stats.numHoras
    m = new HashMap()
    for target in @game().players()
      prob = (if target == @player() then tsumoHoraProb else (1 - tsumoHoraProb) / 3)
      m.set(@getHoraFactors(actor, target), prob)
    return new ProbDist(m)

  getHoraFactors: (actor, target) ->
    if target == actor
      if actor == @game().oya()
        return (for p in @game().players()
          if p == actor then 1 else -1 / 3
        )
      else
        return (for p in @game().players()
          if p == actor
            1
          else if p == @game().oya()
            -1 / 2
          else
            -1 / 4
        )
    else
      return (for p in @game().players()
        if p == actor
          1
        else if p == target
          -1
        else
          0
      )

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
    totalPointsFreqsVector = ({} for _ in [0...(Pai.NUM_IDS + 1)])
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
          points = pointsVector[pid]
          totalPointsVector[pid] += points
          if !(points of totalPointsFreqsVector[pid])
            totalPointsFreqsVector[pid][points] = 0
          ++totalPointsFreqsVector[pid][points]
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
        horaPointsDist: new ProbDist(new HashMap(
            [parseInt(points), freq / totalHoraVector[pid]] for points, freq of totalPointsFreqsVector[pid]))
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

  getAverageRank: (scoreChangesDist) ->
    myId = @player().id
    winsDist = new ProbDist([0, 0, 0, 0])
    for other in @game().players()
      if other == @player() then continue
      winProb = @getWinProb(scoreChangesDist, other)
      d = new ProbDist(new HashMap([
          [[0, 0, 0, 0], 1 - winProb],
          [((if i == other.id then 1 else 0) for i in [0...4]), winProb]
      ]))
      winsDist = ProbDist.add(winsDist, d)
    rankDist = winsDist.mapValue (wins) =>
      4 - (Util.count wins, (w) => w == 1)
    return rankDist.expected()

  getWinProb: (scoreChangesDist, other) ->
    # TODO Change this considering renchan.
    nextKyoku = Game.getNextKyoku(@game().bakaze(), @game().kyokuNum())
    myId = @player().id
    myPos = @game().getDistance(@player(), @game().chicha())
    otherPos = @game().getDistance(other, @game().chicha())
    key = printf("%s%d,%d,%d", nextKyoku.bakaze, nextKyoku.kyokuNum, myPos, otherPos)
    winProbs = @_stats.winProbsMap[key]
    relativeScoreDist = scoreChangesDist.mapValue (scoreChanges) =>
      (@player().score + scoreChanges[myId]) - (other.score + scoreChanges[other.id])
    winProb = 0
    relativeScoreDist.dist().forEach (relativeScore, prob) =>
      winProb += prob * @getWinProbFromRelativeScore(relativeScore, winProbs, myPos, otherPos)
    return winProb

  getWinProbFromRelativeScore: (relativeScore, winProbs, myPos, otherPos) ->
    if winProbs && (relativeScore of winProbs)
      return winProbs[relativeScore]
    else
      # abs(relativeScore) is so big that statistics are missing,
      # or the current kyoku is S-4 (orasu).
      if myPos < otherPos
        return if relativeScore >= 0 then 1 else 0
      else
        return if relativeScore > 0 then 1 else 0

  setDangerEstimatorForTest: (estimator) ->
    @_dangerEstimator = estimator

  setTenpaiProbEstimatorForTest: (estimator) ->
    @_tenpaiProbEstimator = estimator

  setStatsForTest: (stats) ->
    @_stats = stats

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
