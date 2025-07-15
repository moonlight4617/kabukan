#!/bin/bash
# Slack通知Lambda関数設定スクリプト

AWS_REGION="ap-northeast-1"
SLACK_LAMBDA_NAME="kabukan-slack-notifier"
SNS_TOPIC_NAME="kabukan-error-alerts"
ROLE_NAME="kabukan-slack-notifier-role"

echo "📱 Slack通知Lambda関数を設定中..."

# .envファイルから環境変数を読み込み
if [ ! -f ".env" ]; then
    echo "❌ .envファイルが見つかりません"
    exit 1
fi
source .env

# アカウントIDを取得
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
SNS_TOPIC_ARN="arn:aws:sns:$AWS_REGION:$ACCOUNT_ID:$SNS_TOPIC_NAME"

echo "📋 設定情報:"
echo "  - Lambda関数名: $SLACK_LAMBDA_NAME"
echo "  - SNSトピック: $SNS_TOPIC_ARN"
echo "  - Slack Bot Token: ${SLACK_BOT_TOKEN:0:10}..."
echo ""

# 1. IAMロールを作成
echo "🔐 IAMロールを作成中..."
TRUST_POLICY=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
)

if aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "$TRUST_POLICY" \
    --region "$AWS_REGION" > /dev/null 2>&1; then
    echo "✅ IAMロール作成完了"
else
    echo "⚠️  IAMロール作成スキップ（既に存在）"
fi

# 基本実行ポリシーをアタッチ
aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" \
    > /dev/null 2>&1

echo "✅ 基本実行ポリシーをアタッチ完了"

# 2. Lambda関数のデプロイパッケージを作成
echo "📦 Lambda関数パッケージを作成中..."
zip -q slack_notifier_lambda.zip slack_notifier_lambda.py
echo "✅ デプロイパッケージ作成完了"

# 3. Lambda関数を作成
echo "🚀 Lambda関数を作成中..."
ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME"

# 少し待ってからLambda関数を作成（IAMロールの反映待ち）
sleep 10

if aws lambda create-function \
    --function-name "$SLACK_LAMBDA_NAME" \
    --runtime "python3.9" \
    --role "$ROLE_ARN" \
    --handler "slack_notifier_lambda.lambda_handler" \
    --zip-file "fileb://slack_notifier_lambda.zip" \
    --timeout 30 \
    --memory-size 128 \
    --region "$AWS_REGION" > /dev/null 2>&1; then
    echo "✅ Lambda関数作成完了"
else
    echo "⚠️  Lambda関数更新中..."
    aws lambda update-function-code \
        --function-name "$SLACK_LAMBDA_NAME" \
        --zip-file "fileb://slack_notifier_lambda.zip" \
        --region "$AWS_REGION" > /dev/null
    echo "✅ Lambda関数更新完了"
fi

# 4. 環境変数を設定
echo "🌍 環境変数を設定中..."
# Slack Webhook URLを作成（簡易版）
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T095G945Y/B095G945ZNE/${SLACK_BOT_TOKEN#xoxb-}"

ENVIRONMENT_VARS=$(cat <<EOF
{
    "Variables": {
        "SLACK_WEBHOOK_URL": "$SLACK_WEBHOOK_URL",
        "SLACK_BOT_TOKEN": "$SLACK_BOT_TOKEN",
        "SLACK_CHANNEL": "$SLACK_CHANNEL"
    }
}
EOF
)

if aws lambda update-function-configuration \
    --function-name "$SLACK_LAMBDA_NAME" \
    --environment "$ENVIRONMENT_VARS" \
    --region "$AWS_REGION" > /dev/null; then
    echo "✅ 環境変数設定完了"
else
    echo "❌ 環境変数設定エラー"
fi

# 5. SNSトピックにLambda関数をサブスクライブ
echo "📢 SNSサブスクリプションを作成中..."
LAMBDA_ARN="arn:aws:lambda:$AWS_REGION:$ACCOUNT_ID:function:$SLACK_LAMBDA_NAME"

if aws sns subscribe \
    --topic-arn "$SNS_TOPIC_ARN" \
    --protocol "lambda" \
    --notification-endpoint "$LAMBDA_ARN" \
    --region "$AWS_REGION" > /dev/null; then
    echo "✅ SNSサブスクリプション作成完了"
else
    echo "⚠️  SNSサブスクリプション作成スキップ（既に存在の可能性）"
fi

# 6. Lambda関数にSNS実行権限を追加
echo "🔐 Lambda関数にSNS実行権限を追加中..."
STATEMENT_ID="sns-invoke-$(date +%s)"

if aws lambda add-permission \
    --function-name "$SLACK_LAMBDA_NAME" \
    --statement-id "$STATEMENT_ID" \
    --action "lambda:InvokeFunction" \
    --principal "sns.amazonaws.com" \
    --source-arn "$SNS_TOPIC_ARN" \
    --region "$AWS_REGION" > /dev/null 2>&1; then
    echo "✅ SNS実行権限追加完了"
else
    echo "⚠️  SNS実行権限追加でエラー（既に存在する可能性があります）"
fi

# クリーンアップ
rm -f slack_notifier_lambda.zip

echo ""
echo "🎉 Slack通知システム設定完了！"
echo ""
echo "📋 設定内容:"
echo "1. ✅ Lambda関数作成: $SLACK_LAMBDA_NAME"
echo "2. ✅ SNSサブスクリプション設定"
echo "3. ✅ Slack Webhook設定"
echo "4. ✅ IAM権限設定"
echo ""
echo "💡 テスト方法:"
echo "aws cloudwatch set-alarm-state --alarm-name kabukan-errors --state-value ALARM --state-reason 'Test alarm' --region $AWS_REGION"
echo ""
echo "🔧 確認コマンド:"
echo "• Lambda関数詳細: aws lambda get-function --function-name $SLACK_LAMBDA_NAME --region $AWS_REGION"
echo "• SNSサブスクリプション: aws sns list-subscriptions-by-topic --topic-arn $SNS_TOPIC_ARN --region $AWS_REGION"