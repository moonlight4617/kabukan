# AWS Lambda Layers 詳細設定手順書

## 📋 概要

Lambda Layersを使用して、大きなライブラリ（pandas, numpy等）をLayer化し、Lambda本体を軽量化します。

### 構成
- **Lambda Layer**: 重いライブラリ（pandas, numpy, google-api-python-client等）
- **Lambda本体**: アプリケーションコード + 軽量ライブラリ

---

## 🔧 手順1: Lambda Layer の作成

### 1.1 Layer用パッケージ作成

```bash
# Layer用パッケージを作成
./create_lambda_layer.sh
```

これにより以下が作成されます：
- `lambda_layer.zip`: Layer用zipファイル（約50-70MB）
- 重いライブラリが含まれる

### 1.2 AWS コンソールでLayer作成

1. **AWSコンソール** → **Lambda** → **レイヤー**
2. 「**レイヤーの作成**」をクリック
3. 設定値:
   ```
   名前: investment-advice-dependencies
   説明: pandas, numpy等の重いライブラリ
   ライセンス情報: (オプション)
   互換ランタイム: Python 3.9, Python 3.10, Python 3.11 にチェック
   互換アーキテクチャ: x86_64 にチェック
   ```
4. 「**アップロード**」で `lambda_layer.zip` を選択
5. 「**作成**」をクリック

### 1.3 Layer ARN の取得

作成後に表示される **Layer ARN** をメモしてください：
```
arn:aws:lambda:ap-northeast-1:123456789012:layer:investment-advice-dependencies:1
```

---

## 🔧 手順2: Lambda本体の作成

### 2.1 軽量パッケージ作成

```bash
# Lambda本体用の軽量パッケージを作成
./deploy_lambda_with_layer.sh
```

これにより以下が作成されます：
- `lambda_deploy_light.zip`: Lambda本体用zipファイル（約10-20MB）
- アプリケーションコード + 軽量ライブラリのみ

### 2.2 AWS コンソールでLambda関数作成

1. **AWSコンソール** → **Lambda** → **関数**
2. 「**関数の作成**」をクリック
3. 設定値:
   ```
   関数名: investment-advice-notifier
   ランタイム: Python 3.9以上
   アーキテクチャ: x86_64
   実行ロール: 基本的なLambda実行ロールを持つ新しいロールを作成
   関数 URL を有効化: ❌ 無効
   VPC を有効化: ❌ 無効
   ```

### 2.3 コードアップロード

1. 「**コード**」タブを選択
2. 「**アップロード元**」→「**.zipファイル**」を選択
3. `lambda_deploy_light.zip` をアップロード
4. **ハンドラー**: `index.lambda_handler` に設定

### 2.4 ⚠️ 重要: Layerの追加

1. 「**レイヤー**」タブを選択
2. 「**レイヤーを追加**」をクリック
3. 「**カスタムレイヤー**」を選択
4. **レイヤー**: `investment-advice-dependencies` を選択
5. **バージョン**: `1` を選択
6. 「**追加**」をクリック

### 2.5 環境変数の設定

「**設定**」→「**環境変数**」で以下を設定:

```
GOOGLE_SHEETS_CREDENTIALS_PATH=/tmp/credentials.json
SPREADSHEET_ID=1yU1yCsUpYArMBjnGl-LWMlgJ5VpCehEVbKN8dAauYzU
GOOGLE_API_KEY=your_gemini_api_key
SLACK_BOT_TOKEN=xoxb-your-slack-bot-token
SLACK_CHANNEL=C095G945ZNE

# S3経由の場合
CREDENTIALS_S3_BUCKET=your-credentials-bucket
CREDENTIALS_S3_KEY=credentials/google-sheets-credentials.json
```

### 2.6 基本設定の調整

「**設定**」→「**一般設定**」で以下を調整:
```
タイムアウト: 5分（300秒）
メモリ: 512MB以上
一時ストレージ: 512MB（デフォルト）
```

---

## 🔧 手順3: IAM権限の設定

### 3.1 S3アクセス権限の追加（S3経由の場合）

1. **IAM** → **ロール** → Lambda実行ロールを選択
2. 「**ポリシーをアタッチ**」→「**インラインポリシーの作成**」
3. JSON形式で以下を設定:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::your-credentials-bucket/*"
        }
    ]
}
```

---

## 🔧 手順4: EventBridge設定

### 4.1 スケジュールルール作成

1. **EventBridge** → **ルール** → 「**ルールの作成**」
2. 設定値:
   ```
   名前: daily-investment-advice
   説明: 毎日の投資アドバイス通知
   イベントパターン: スケジュール
   スケジュール式: cron(0 21 * * ? *)  # 毎日UTC21:00 = JST06:00
   ```

### 4.2 ターゲット設定

1. **ターゲット**: Lambda関数
2. **関数**: `investment-advice-notifier`
3. **入力の設定**: 定数（JSONテキスト）
   ```json
   {
     "source": "eventbridge",
     "trigger": "daily-schedule"
   }
   ```

---

## 🧪 手順5: テスト実行

### 5.1 手動テスト

1. Lambdaコンソール → 「**テスト**」タブ
2. テストイベント作成:
   ```json
   {
     "source": "manual-test",
     "trigger": "test-execution"
   }
   ```
3. 「**テスト**」実行
4. **CloudWatch Logs** でログ確認

### 5.2 Layer動作確認

実行ログで以下を確認:
```
✅ pandas, numpy等のライブラリが正常にインポートされている
✅ エラーなく処理が完了している
✅ Slackに通知が届いている
```

---

## 📊 サイズ比較

| 項目 | サイズ |
|------|--------|
| **従来版（Layer無し）** | 約80MB |
| **Layer版 - Layer** | 約50-70MB |
| **Layer版 - Lambda本体** | 約10-20MB |
| **合計** | 約60-90MB |

### メリット
- ✅ Lambda本体が50MB制限内に収まる
- ✅ アップロード時間短縮
- ✅ 複数のLambda関数でLayerを再利用可能
- ✅ ライブラリのバージョン管理が楽

---

## 🔄 更新手順

### Layerの更新
1. `./create_lambda_layer.sh` でLayer再作成
2. AWSコンソールでLayer新バージョン作成
3. Lambda関数のLayerバージョンを更新

### Lambda本体の更新
1. `./deploy_lambda_with_layer.sh` で本体再作成
2. AWSコンソールでzipファイル再アップロード

---

## ❗ トラブルシューティング

### よくあるエラー
| エラー | 原因 | 解決方法 |
|--------|------|----------|
| `No module named 'pandas'` | Layerが追加されていない | Lambda関数にLayerを追加 |
| `Unable to import module` | パッケージ構成エラー | zipファイルの構成を確認 |
| `Task timed out` | メモリ・タイムアウト不足 | 設定値を増加 |

### デバッグのコツ
1. CloudWatch Logsで詳細エラーを確認
2. Layer ARNが正しく設定されているか確認
3. 環境変数の値を確認

---

これで**Lambda Layers**を利用した軽量で効率的なデプロイが可能になります！
