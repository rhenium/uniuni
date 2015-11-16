# uniuni
[rhe.jp](https://rhe.jp) 用の Rack アプリケーション

Rack 対応 HTTP/2 サーバー [plum](https://github.com/rhenium/plum) と組み合わせて使用することを想定しています。

plum と組み合わせた場合、スタイルシート・画像等はクライアントにサーバープッシュされます。

## サンプル
* TLS あり: [https://rhe.jp/](https://rhe.jp/)
* TLS なし: [http://rhe.jp/](http://rhe.jp/)

## 使用方法
```sh
bundle install
vi config.yml
bin/uniuni analyze # ドキュメントルート以下の HTML をパースしてサーバープッシュのためのマップを作る
vi plum.rb # plum の設定、plum のページを参照
plum -C plum.rb # サーバーの起動
```

## 必要な環境
[rhenium/plum](https://github.com/rhenium/plum) と同じ

## ライセンス
MIT License
