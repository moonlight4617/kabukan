# AWS Lambda デプロイ手順書

## 1. 前提条件

- AWSアカウントが作成済み
- Google Sheets API認証情報を取得済み
- Gemini API キーを取得済み
- Slack Bot Token を取得済み

## 2. Lambda関数の作成

### 2.1 AWS コンソールでLambda作成

1. AWSコンソールにログイン
2. Lambdaサービスに移動
3. 「関数の作成」をクリック
4. 設定値:
   - **関数名**: `investment-advice-notifier`
   - **ランタイム**: Python 3.9 以上
   - **アーキテクチャ**: x86_64
   - **実行ロール**: 「基本的なLambda実行ロールを持つ新しいロールを作成」

### 2.2 パッケージサイズの最適化（必要に応じて）

現在のパッケージは80MBと大きいため、AWS Lambda Layersの使用を推奨:

```bash
# 軽量版の作成（pandasを除外）
# requirements_lambda_light.txt を作成し、pandasを除外
# データ分析をより軽量なライブラリで実装
```

### 2.3 コードのアップロード

1. Lambdaコンソールで「コード」タブを選択
2. 「アップロード」→「.zipファイル」を選択
3. `lambda_deploy.zip` をアップロード
4. **ハンドラー**を `index.lambda_handler` に設定

## 3. 環境変数の設定

Lambdaコンソールの「設定」→「環境変数」で以下を設定:

```
GOOGLE_SHEETS_CREDENTIALS_PATH=/tmp/credentials.json
SPREADSHEET_ID=1yU1yCsUpYArMBjnGl-LWMlgJ5VpCehEVbKN8dAauYzU
GOOGLE_API_KEY=your_gemini_api_key
SLACK_BOT_TOKEN=xoxb-your-slack-bot-token
SLACK_CHANNEL=C095G945ZNE
```

### Google認証情報の設定（2つの方法）

#### 方法A: S3経由（推奨）
```
CREDENTIALS_S3_BUCKET=your-credentials-bucket
CREDENTIALS_S3_KEY=credentials/google-sheets-credentials.json
```

#### 方法B: 環境変数直接設定
```
GOOGLE_CREDENTIALS_JSON={"type":"service_account"...}
```

## 4. IAM権限の設定

### 4.1 基本実行ロール
Lambda関数には以下の権限が必要:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        }
    ]
}
```

### 4.2 S3アクセス権限（方法Aの場合）
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

## 5. EventBridge（CloudWatch Events）の設定

### 5.1 ルールの作成

1. EventBridgeコンソールに移動
2. 「ルールの作成」をクリック
3. 設定値:
   - **名前**: `daily-investment-advice`
   - **説明**: `毎日の投資アドバイス通知`
   - **イベントパターン**: スケジュール
   - **スケジュール式**: `cron(0 21 * * ? *)` (毎日UTC21:00 = JST06:00)

### 5.2 ターゲットの設定

1. **ターゲット**: Lambda関数
2. **関数**: `investment-advice-notifier`
3. **入力の設定**: 「定数（JSONテキスト）」
   ```json
   {
     "source": "eventbridge",
     "trigger": "daily-schedule"
   }
   ```

## 6. Lambda関数の設定調整

### 6.1 基本設定
- **タイムアウト**: 5分（300秒）
- **メモリ**: 512MB以上推奨
- **一時ストレージ**: 512MB（デフォルト）

### 6.2 同時実行数
- **予約済み同時実行**: 1（コスト削減・重複実行防止）

## 7. テスト手順

### 7.1 手動テスト

1. Lambdaコンソールで「テスト」タブを選択
2. テストイベントを作成:
   ```json
   {
     "source": "manual-test",
     "trigger": "test-execution"
   }
   ```
3. 「テスト」ボタンをクリック
4. CloudWatch Logsで実行ログを確認

### 7.2 EventBridgeテスト

1. EventBridgeルール画面で「テストイベントを送信」
2. Slackに通知が届くことを確認

## 8. 監視・運用

### 8.1 CloudWatch メトリクス
- 実行回数
- エラー回数
- 実行時間

### 8.2 CloudWatch アラーム
```bash
# エラー率が50%を超えた場合のアラーム
aws cloudwatch put-metric-alarm \
  --alarm-name "LambdaErrorRate" \
  --alarm-description "Lambda error rate is high" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold
```

### 8.3 SNS通知設定
Lambda関数でエラーが発生した場合、管理者にメール通知を設定可能。

## 9. コスト見積もり（月額）

### 無料枠内の場合
- **Lambda実行**: 月30回 → 無料
- **EventBridge**: 月30イベント → 無料
- **CloudWatch Logs**: 少量 → ほぼ無料
- **S3**: 認証情報ファイル1個 → ほぼ無料

### 合計: **月額 0〜数円**

## 10. トラブルシューティング

### 10.1 よくあるエラー

| エラー | 原因 | 解決方法 |
|--------|------|----------|
| `Task timed out` | 処理時間が長すぎる | タイムアウト値を増加 |
| `Unable to import module` | パッケージが見つからない | zipファイルの構成を確認 |
| `Permission denied` | IAM権限不足 | 適切なポリシーを追加 |
| `Invalid signature` | Slack認証エラー | Bot Tokenを再確認 |

### 10.2 デバッグ手順

1. CloudWatch Logsでエラーメッセージを確認
2. 環境変数の値を確認
3. IAM権限を確認
4. ネットワーク接続を確認

## 11. アップデート手順

### コード変更時
1. ローカルでコード修正
2. `./deploy_lambda.sh` でパッケージ再作成
3. Lambdaコンソールでzipファイル再アップロード

### 設定変更時
1. 環境変数を更新
2. テスト実行で動作確認

---

**注意事項:**
- 本番環境では、必ずテスト環境での動作確認を行ってください
- API Keyやトークンは適切に管理し、定期的にローテーションしてください
- 大量のデータ処理が必要な場合は、メモリ・タイムアウト値を調整してください
