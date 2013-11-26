## 概要

[Mjai 麻雀AI対戦サーバ](http://gimite.net/pukiwiki/index.php?Mjai%20%CB%E3%BF%FDAI%C2%D0%C0%EF%A5%B5%A1%BC%A5%D0) 用の麻雀AIです。


## 仕組み

[自己対戦の牌譜のサンプル](http://gimite.net/mjai/samples/manue011.tonnan/2013-11-26-143619.mjson.html)

まず、それぞれの打牌をした場合について、以下の数値を算出します。これらのスコアは、上の牌譜のデバッグ出力で確認できます。

* horaProb / Hora probability / 和了率
  * その打牌をした場合に、この局で自分が和了できる確率。
  * モンテカルロで求める。終局までにNツモあるとすると、ランダムにN枚引いて、手牌13枚+N枚で和了を作れるかどうかをチェック。これを1000回繰り返す。
  * 実際には高速化のために「今の手牌から和了するための必要牌」をあらかじめ求めておき、ランダムに引いたN枚に必要牌が含まれるかをチェックしている。
* avgHoraPt / Average hora points / 平均和了点
  * 自分が和了した場合の平均和了点。
  * horaProbと同時にモンテカルロで求める。手牌13枚+N枚で作れた和了の点数の平均。
* unsafeProb / Unsafe probability / 放銃率
  * その打牌で誰かに放銃する確率。
  * 今のところ、リーチしている人への放銃だけを考慮。
  * 決定木学習を使って推定。特徴量は「字牌」「スジ」など。学習データは天鳳の牌譜。[統計による麻雀危険牌分析](http://gimite.net/pukiwiki/index.php?%C5%FD%B7%D7%A4%CB%A4%E8%A4%EB%CB%E3%BF%FD%B4%ED%B8%B1%C7%D7%CA%AC%C0%CF)参照。
* avgHojuPt / Average hoju points / 平均放銃点
  * 放銃した場合に払う額の平均。
  * 今のところは自己対戦のログから求めた固定値6265点。牌譜のデバッグ出力にはない。

以上の数値から、この局で自分が得る点数の期待値(expPt)を求めることができます。

* expPt = (1 - unsafeProb) * horaProb * avgHoraPt - unsafeProb * avgHojuPt

このexpPtが最大となる打牌を採用します。

「鳴くか、鳴かないか」「リーチか、ダマか」も同様の方法で判断します。


## ライセンス

"New BSD Licence" です。


## 作者

[Hiroshi Ichikawa](http://gimite.net/pukiwiki/index.php?%CF%A2%CD%ED%C0%E8)
