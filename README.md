# 株式投資アドバイスアプリケーション

Google Sheetsに保存された株式ポートフォリオを分析し、AIによる投資アドバイスを提供するPythonアプリケーションです。

## 機能概要

### 🔹 主な機能
- **Google Sheets統合**: スプレッドシートから保有銘柄リストを自動取得
- **リアルタイム株価取得**: yfinanceを使用して最新の株価情報を取得
- **ポートフォリオ分析**: 
  - 総資産価値の計算
  - 日次損益の算出
  - リスク評価（変動性、集中度）
  - 分散状況の分析
- **AI投資アドバイス**: Gemini API（google-generativeai Pythonライブラリ）を通じた売買戦略の提案
- **Slack統合**: 
  - 投資アドバイスの自動Slack通知
  - Slack BotによるAI投資相談機能

### 🔹 技術スタック
- **Python 3.x**
- **Google Sheets API** (gspread)
- **Yahoo Finance API** (yfinance)
- **Gemini API** (google-generativeai Pythonライブラリ)
- **Slack API** (slack-sdk)
- **Flask** (Webhook サーバー)
- **pandas** (データ処理)

## セットアップ

### 1. 依存関係のインストール
```bash
pip install -r requirements.txt
```

### 2. 環境変数の設定
```bash
cp .env.example .env
```

`.env`ファイルを編集して以下の情報を設定：
```env
# Google Sheets API設定
GOOGLE_SHEETS_CREDENTIALS_PATH=path/to/your/service-account-credentials.json
SPREADSHEET_ID=your_google_spreadsheet_id

# Gemini API設定
GOOGLE_API_KEY=your_gemini_api_key

# Slack API設定
SLACK_BOT_TOKEN=xoxb-your-bot-token-here
SLACK_SIGNING_SECRET=your-signing-secret-here
SLACK_CHANNEL=#investment-advice

# オプション設定
WORKSHEET_NAME=シート1
STOCK_SYMBOL_COLUMN=証券コード
QUANTITY_COLUMN=保有株数
```

### 3. Google Sheets APIの準備

#### 3.1 サービスアカウントの作成
1. [Google Cloud Console](https://console.cloud.google.com/)にアクセス
2. プロジェクトを作成または選択
3. Google Sheets APIを有効化
4. サービスアカウントを作成
5. 認証情報（JSONファイル）をダウンロード

#### 3.2 スプレッドシートの準備
以下の形式でスプレッドシートを作成：

| 証券コード | 銘柄名       | 保有株数 | 取得価格 |
|----------|------------|--------|--------|
| 7203     | トヨタ自動車 | 100    | 2500   |
| 6758     | ソニーグループ | 50     | 3500   |
| 4519     | 中外製薬     | 200    | 6800   |

**重要**: サービスアカウントのメールアドレスにスプレッドシートの編集権限を付与してください。

### 4. Gemini APIキーの取得
1. [Google AI Studio](https://makersuite.google.com/app/apikey)にアクセス
2. APIキーを生成
3. `.env`ファイルに設定

### 5. Slack APIの設定
1. [Slack API](https://api.slack.com/apps)にアクセス
2. 新しいアプリを作成
3. 「OAuth & Permissions」でBotトークンを取得
4. 「Event Subscriptions」でWebhook URLを設定
5. 必要な権限を付与：
   - `chat:write`
   - `channels:read`
   - `im:read`
   - `mpim:read`
   - `groups:read`
6. `.env`ファイルに設定

## 使用方法

### 🚀 開発環境（ngrok使用）

#### クイックスタート
```bash
# 1. 基本的なポートフォリオ分析実行
python main_dev.py

# 2. Slack Botサーバー起動（別ターミナル）
python slack_bot_dev.py

# 3. ngrok起動（さらに別ターミナル）
./start_ngrok.sh
```

#### 詳細手順
1. **依存関係インストール**:
   ```bash
   pip install -r requirements.txt
   ```

2. **環境変数設定**: `.env`ファイルを作成
   ```env
   # 必須
   GOOGLE_SHEETS_CREDENTIALS_PATH=./credentials_config/credentials.json
   SPREADSHEET_ID=your_spreadsheet_id
   GOOGLE_API_KEY=your_gemini_api_key
   
   # Slack連携用（開発時）
   SLACK_BOT_TOKEN=xoxb-your-bot-token
   SLACK_SIGNING_SECRET=your-signing-secret
   SLACK_CHANNEL=#investment-advice
   ```

3. **Slack App作成**:
   - [Slack API](https://api.slack.com/apps)で新アプリ作成
   - Bot Token取得（`chat:write`権限付与）
   - Event Subscriptions有効化

4. **ngrok起動**:
   ```bash
   ./start_ngrok.sh
   # または
   ngrok http 5000
   ```

5. **Slack AppにWebhook URL設定**:
   - Event Subscriptions → Request URL: `https://xxxx.ngrok.io/slack/events`
   - Bot Events: `message.channels`, `message.im`

6. **Slack Botサーバー起動**:
   ```bash
   python slack_bot_dev.py
   ```

7. **テスト**:
   - SlackでBot宛てにメンション: `@bot トヨタ株について教えて`
   - DMで直接質問も可能

### 📱 本番環境（AWS Lambda + API Gateway）

*本番環境のデプロイ方法は別途ドキュメント化予定*

### Slack Botサーバーの起動
```bash
python slack_bot.py
```

### Slack Botの使用方法
1. 設定したチャンネルで投資アドバイスを受信
2. Bot宛てに質問をメンション（例：`@投資bot トヨタ株について教えて`）
3. DMで直接質問も可能

### 基本的な実行
```bash
python main.py
```

### ヘルプの表示
```bash
python main.py --help
```

### 実行例
```bash
$ python main.py
=== 株式投資アドバイスアプリケーション ===

1. データフェッチャーを初期化中...
Google Sheets接続成功

2. ポートフォリオと株価情報を取得中...
ポートフォリオ取得完了: 4銘柄
AAPL: $150.25 (+1.35%)
GOOGL: $2,800.50 (+1.82%)
MSFT: $420.75 (-0.45%)
TSLA: $245.30 (+2.10%)

3. ポートフォリオ分析を実行中...

4. 分析レポートを生成中...
=== ポートフォリオ分析レポート ===
生成日時: 2024-01-15 10:30:00

【概要】
総資産価値: $18,740.25
保有銘柄数: 4銘柄

【パフォーマンス】
日次損益: $287.50
日次リターン: +1.56%
勝ち銘柄: 3銘柄
負け銘柄: 1銘柄
勝率: 75.0%

【リスク評価】
リスクレベル: 中
ポートフォリオ変動性: 1.68%
最大日次損失: -0.45%

【分散状況】
上位5銘柄集中度: 100.0%
分散状況: 要改善

5. AI投資アドバイスを取得中...
=== AI投資アドバイス ===
[Gemini APIからの投資アドバイスが表示されます]

=== 処理完了 ===
```

## テスト

### 基本テストの実行
```bash
python tests/test_portfolio.py --basic
```

### 単体テストの実行
```bash
python tests/test_portfolio.py --unittest
```

### Google Sheets接続テスト
```bash
python tests/test_sheets.py
```

## ファイル構成

```
claude-code/
├── main.py                 # メインアプリケーション（本番用）
├── main_dev.py            # メインアプリケーション（開発用）
├── config.py              # 設定管理
├── data_fetcher.py        # データ取得（Google Sheets、株価）
├── analyzer.py            # ポートフォリオ分析
├── mcp_client.py          # Gemini API連携
├── slack_client.py        # Slack API連携
├── slack_bot.py           # Slack Bot Webhook サーバー（本番用）
├── slack_bot_dev.py       # Slack Bot Webhook サーバー（開発用）
├── start_ngrok.sh         # ngrok起動スクリプト
├── dev_start.sh           # 開発環境統合起動スクリプト
├── requirements.txt       # 依存関係（slack-sdk、flask含む）
├── .env.example          # 環境変数テンプレート
├── CLAUDE.md             # Claude Code用ガイド
├── README.md             # このファイル
└── tests/
    ├── test_portfolio.py  # ポートフォリオテスト
    └── test_sheets.py     # Google Sheetsテスト
```

## トラブルシューティング

### よくある問題

**1. Google Sheets認証エラー**
```
Google Sheets接続エラー: [Errno 2] No such file or directory
```
- サービスアカウントのJSONファイルパスを確認
- `.env`ファイルの`GOOGLE_SHEETS_CREDENTIALS_PATH`を正しく設定

**2. スプレッドシート読み込みエラー**
```
スプレッドシート読み込みエラー: Worksheet not found
```
- スプレッドシートIDが正しいか確認
- サービスアカウントに共有権限があるか確認

**3. 株価取得エラー**
```
XXXXの株価取得エラー: No data found
```
- 株式銘柄コードが正しいか確認
- 市場の営業時間外やデータ遅延の可能性

**4. Gemini API接続エラー**
```
Gemini API初期化エラー: APIキーが不正です
```
- `.env`のGOOGLE_API_KEYが正しいか確認
- google-generativeaiライブラリがインストールされているか確認

### デバッグ方法

1. **環境変数の確認**:
   ```bash
   python -c "import os; print(os.getenv('GOOGLE_API_KEY'))"
   ```

2. **Google Sheets接続テスト**:
   ```bash
   python tests/test_sheets.py
   ```

3. **基本機能テスト**:
   ```bash
   python tests/test_portfolio.py --basic
   ```

## 貢献

1. このリポジトリをフォーク
2. 機能ブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add amazing feature'`)
4. ブランチをプッシュ (`git push origin feature/amazing-feature`)
5. プルリクエストを作成

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。

## 注意事項

- このアプリケーションは教育目的で作成されており、投資アドバイスは参考程度に留めてください
- 実際の投資判断は自己責任で行ってください
- APIキーや認証情報は適切に管理し、公開リポジトリにコミットしないでください
- 株価データには遅延が生じる場合があります

## サポート

質問やバグ報告は、GitHubのIssuesページでお願いします。