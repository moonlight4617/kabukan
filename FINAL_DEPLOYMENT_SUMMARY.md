# 🎉 AWS Lambda投資アドバイスシステム - 最終デプロイ構成

## ✅ 最終構成（5つのLayers + Lambda関数）

### 📦 Lambda Layers（AWS 50MB制限対応済み）

1. **lambda_layer1a_pandas.zip** (42MB) ✅
   - pandas==2.3.1
   - numpy>=1.22.4
   - python-dateutil, pytz, tzdata, six
   - 用途: データ処理の基盤

2. **lambda_layer1b2_scraping.zip** (1MB) ✅
   - beautifulsoup4>=4.9.3
   - tqdm>=4.66.4
   - frozendict>=2.4.2
   - 用途: Webスクレイピング

3. **lambda_layer1c_web.zip** (11MB) ✅
   - websockets>=13.0
   - curl_cffi>=0.7
   - protobuf>=3.19.0
   - cffi, pycparser, platformdirs, peewee
   - 用途: Web/Network通信

4. **lambda_layer2_google.zip** (30MB) ✅
   - google-generativeai==0.8.5
   - grpcio==1.73.1
   - google-auth, google-api-core等
   - 用途: Google AI API接続

5. **lambda_layer_finance_alternative.zip** (1MB) ✅
   - requests>=2.31.0
   - urllib3, idna, charset_normalizer, certifi
   - 用途: 金融API接続（yfinance代替）

### 📦 Lambda関数本体

- **lambda_deploy_light.zip** (16MB) ✅
  - main.py, analyzer.py, config.py等
  - gspread（Googleスプレッドシート）
  - slack_sdk（Slack通知）
  - boto3（AWS SDK）
  - requests（HTTP通信）

## 🚀 デプロイ手順

### 1. S3バケット作成（推奨）
```bash
aws s3 mb s3://your-lambda-layers-bucket
```

### 2. 自動デプロイスクリプト実行
```bash
chmod +x deploy_quad_layers_via_s3.sh
# スクリプト内のS3_BUCKETとAWS_REGIONを編集
./deploy_quad_layers_via_s3.sh
```

### 3. 手動デプロイ（代替）
各LayerをAWSコンソールから個別にアップロード
- 10MB以下: 直接アップロード可能
- 10MB以上: S3経由でアップロード必要

### 4. Lambda関数設定
Lambda関数に以下5つのLayerを順序通りに追加:
1. investment-advice-layer-pandas
2. investment-advice-layer-scraping
3. investment-advice-layer-web
4. investment-advice-layer-google
5. investment-advice-layer-finance-alternative

### 5. EventBridge設定
```json
{
  "schedule": "cron(0 21 * * ? *)",
  "timezone": "UTC",
  "description": "Daily at 06:00 JST"
}
```

## ⚠️ 重要な注意点

### yfinanceライブラリについて
- **問題**: yfinanceとその依存関係が50MB制限を超過
- **解決策**: 代替APIを使用
  - Alpha Vantage API
  - Financial Modeling Prep API
  - IEX Cloud API
  - Yahoo Finance REST API（直接）

### サンプル代替実装
```python
import requests

def get_stock_data_alternative(symbol):
    # Alpha Vantage例
    api_key = "YOUR_API_KEY"
    url = f"https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol={symbol}&apikey={api_key}"
    response = requests.get(url)
    return response.json()

def get_yahoo_finance_data(symbol):
    # Yahoo Finance REST API例
    url = f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol}"
    response = requests.get(url)
    return response.json()
```

## 📋 最終確認事項
- ✅ 5つのLayer全てが50MB以内
- ✅ Lambda関数本体が16MB（10MB超のためS3経由）
- ✅ 合計Layer数5個（AWS制限内）
- ✅ EventBridge連携対応
- ✅ Google AI API統合
- ✅ Slack通知対応
- ✅ Googleスプレッドシート出力対応

## 🎯 運用開始後の流れ
1. 毎日UTC 21:00（JST 06:00）にEventBridgeが起動
2. Lambda関数が投資分析を実行
3. Google AIで市場分析・アドバイス生成
4. 結果をGoogleスプレッドシートに記録
5. Slackで結果通知

これでAWS Lambda投資アドバイスシステムの完全デプロイ準備が完了しました！🎉
