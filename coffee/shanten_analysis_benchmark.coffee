fs = require("fs")
ShantenAnalysis = require("./shanten_analysis")

countVectorToStr = (countVector) ->
  return new PaiSet({array: countVector}).toString()

shuffle = (array, n = array.length) ->
  for i in [0...n]
    j = i + Math.floor(Math.random() * (array.length - i))
    tmp = array[i]
    array[i] = array[j]
    array[j] = tmp
  return array

process = (pids) ->

  result = new ShantenAnalysis(pids)

  console.log("current", Pai.paisToStr(new Pai(pid) for pid in pids))
  currentVector = pidsToCountVector(pids)
  console.log("  shanten", result.shantensu)

  # console.log("goals", result.goals.length)
  for goal in result.goals
    goal.requiredVector = for pid in [0...NUM_PIDS]
      Math.max(goal.countVector[pid] - currentVector[pid], 0)
    goal.throwableVector = for pid in [0...NUM_PIDS]
      Math.max(currentVector[pid] - goal.countVector[pid], 0)
    # console.log("goalVector", countVectorToStr(goal.countVector))
    # console.log("goalRequiredVector", countVectorToStr(goal.requiredVector))
    # console.log("goalThrowableVector", countVectorToStr(goal.throwableVector))
    # console.log("goalMentsus", ([m.type, new Pai(m.firstPid).toString()] for m in goal.mentsus))

  allPids = []
  for pid in [0...NUM_PIDS]
    for i in [0...4]
      allPids.push(pid)
  #console.log("allPais", Pai.paisToStr(new Pai(pid) for pid in allPids))

  numTsumos = 18
  numTries = 1000
  totalHoraVector = (0 for _ in [0...NUM_PIDS])
  for i in [0...numTries]
    shuffle(allPids, numTsumos)
    #allPids = (pai.id() for pai in Pai.strToPais("1m 6m 4p"))
    tsumoVector = pidsToCountVector(allPids[0...numTsumos])
    #console.log("tsumoVector", countVectorToStr(tsumoVector))
    horaVector = (0 for _ in [0...NUM_PIDS])
    #goalVector = (null for _ in [0...NUM_PIDS])
    for goal in result.goals
      achieved = true
      for pid in [0...NUM_PIDS]
        if tsumoVector[pid] < goal.requiredVector[pid]
          achieved = false
      #console.log("goal", countVectorToStr(goal.requiredVector), achieved)
      if achieved
        for pid in [0...NUM_PIDS]
          if goal.throwableVector[pid] > 0
            horaVector[pid] = 1
            #goalVector[pid] = goal
    # s = countVectorToStr(horaVector)
    # if s != ""
    #   console.log("  ", s)
    for pid in [0...NUM_PIDS]
      if horaVector[pid] == 1
        #console.log("  ", new Pai(pid).toString(), ":", countVectorToStr(goalVector[pid].countVector))
        ++totalHoraVector[pid];

  for pid in [0...NUM_PIDS]
    if currentVector[pid] > 0
      console.log("  horaProb", new Pai(pid).toString(), totalHoraVector[pid] / numTries)

  # for pid in [0...NUM_PIDS]
  #   if currentVector[pid] > 0
  #     n = 0
  #     for goal in goals
  #       if goal.countVector[pid] >= currentVector[pid]
  #         #console.log("  ", countVectorToStr(goal.countVector))
  #         n += 1
  #     console.log(new Pai(pid).toString(), n)

  return result

fs.readFileSync("shanten_benchmark_data.num.txt").toString("utf-8").split(/\n/).forEach (line) ->
  if !line then return
  row = line.split(/\ /)
  pids = (parseInt(row[i]) for i in [0...(row.length - 1)])
  expectedShantensu = parseInt(row[row.length - 1])
  result = process(pids)
  if result.shantensu != expectedShantensu
    throw "Shantensu mismatch: #{result.shantensu} != #{expectedShantensu}"
