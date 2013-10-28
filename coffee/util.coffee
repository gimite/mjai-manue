Util =

  attrReader: (cls, names) ->
    for name in names
      ((n) ->
        cls.prototype[n] = (-> this["_#{n}"])
      )(name)

  attrAccessor: (cls, names) ->
    Util.attrReader(cls, names)
    for name in names
      ((n) ->
        capital = n.replace(/^./, (s) -> s.toUpperCase())
        cls.prototype["set#{capital}"] = ((a) -> this["_#{n}"] = a)
      )(name)

  all: (array, func) ->
    for v in array
      if !func(v) then return false
    return true

  any: (array, func) ->
    for v in array
      if func(v) then return true
    return false

module.exports = Util
