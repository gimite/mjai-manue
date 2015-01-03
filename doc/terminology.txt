- probability distribution (probDist, dist)
-- 確率分布。

- probability (prob)
-- 確率。

- hora
-- 和了。

- score
-- あるプレーヤのある時点での点数。

- points
-- 和了の点数。

- fu
-- 30符とかの符。

- fan
-- 飜。

- score change
-- あるプレーヤのある局におけるscoreの変動。

- score changes
-- scoreChanges[player.id]がplayerのscore changeとなるような4要素のベクトル(配列)。 e.g., [8000, -8000, 0, 0]

- player ID
-- 0～3のプレーヤID。

- hora factors
-- horaPoints * horaFactors[player.id] = scoreChanges[player.id] となるような4要素のベクトル(配列)。 
-- ロンなら[1, -1, 0, 0]、子のツモなら[1, -1/2, -1/4, -1/4]など。

- furo
-- 副露。なき。

- pai ID (pid)
-- 牌の種類を表す0～33の整数。

- action
-- 自摸とか打牌とかチーとか。

- metric
-- あるアクション(2mを打牌、など)の結果についての様々な統計値/推定値。

- count vector
-- 牌のmulti setを表すデータ構造の1つ。countVector[pai.id]がpaiの個数となるような配列。

- bit vectors
-- 牌のmulti setを表すデータ構造の1つ。bitVectors[i][pai.id] = (count(pai) > i)となるようなBitVectorの配列。

- rank
-- 順位。1～4の整数。

- statistics (stats)
-- あらかじめ牌譜から収集された統計情報。
