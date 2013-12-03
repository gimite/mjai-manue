Util =

  attrReader: (cls, names) ->
    names.forEach (name) ->
      cls.prototype[name] = (-> this["_#{name}"])

  attrAccessor: (cls, names) ->
    Util.attrReader(cls, names)
    names.forEach (name) ->
      capital = name.replace(/^./, (s) -> s.toUpperCase())
      cls.prototype["set#{capital}"] = ((a) -> this["_#{name}"] = a)

  all: (array, func) ->
    for v in array
      if !func(v) then return false
    return true

  any: (array, func) ->
    for v in array
      if func(v) then return true
    return false

  count: (array, func) ->
    n = 0
    for v in array
      if func(v) then ++n
    return n

  camelCase: (name) ->
    return name.replace(/_(.)/g, (_, ch) -> ch.toUpperCase())

  shuffle: (array, random, n = array.length) ->
    for i in [0...n]
      j = i + Math.floor(random() * (array.length - i))
      tmp = array[i]
      array[i] = array[j]
      array[j] = tmp
    return array

module.exports = Util
