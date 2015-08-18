# plum/server
plum を利用した HTTP/2 サーバー

全くリファクタリングはされていません。動くだけです。

## サンプル
* TLS あり: [https://rhe.jp/](https://rhe.jp/)
* TLS なし: [http://rhe.jp/](http://rhe.jp/)

## 使用方法
```sh
bundle install
cp plum.yml.example plum.yml
vi plum.yml
bin/plum analyze --config plum.yml # サーバープッシュの準備
bin/plum server --config plum.yml # サーバーの起動
```

## 必要な環境
[rhenium/plum](https://github.com/rhenium/plum) と同じ

## ライセンス
MIT License
