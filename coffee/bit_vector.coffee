class BitVector

  constructor: (array) ->
    @data = (0 for _ in [0...Math.ceil(array.length / 32)])
    for i in [0...array.length]
      if array[i]
        @data[i >> 5] |= (1 << (i % 32))

  isSubsetOf: (other) ->
    for i in [0...@data.length]
      if (@data[i] & other.data[i]) != @data[i]
        return false
    return true

  hasIntersectionWith: (other) ->
    for i in [0...@data.length]
      if (@data[i] & other.data[i]) != 0
        return true
    return false

module.exports = BitVector
