#!/bin/bash
# CloudWatchエラー監視とSlack通知設定スクリプト

FUNCTION_NAME="kabukan"
AWS_REGION="ap-northeast-1"
SNS_TOPIC_NAME="kabukan-error-alerts"
SLACK_LAMBDA_NAME="kabukan-slack-notifier"

echo "📊 CloudWatchエラー監視システムを設定中..."

# アカウントIDを取得
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "📋 設定情報:"
echo "  - 監視対象Lambda: $FUNCTION_NAME"
echo "  - リージョン: $AWS_REGION"
echo "  - SNSトピック: $SNS_TOPIC_NAME"
echo "  - Slack通知Lambda: $SLACK_LAMBDA_NAME"
echo ""

# 1. SNSトピックを作成
echo "📢 SNSトピックを作成中..."
SNS_TOPIC_ARN=$(aws sns create-topic \
    --name "$SNS_TOPIC_NAME" \
    --region "$AWS_REGION" \
    --query 'TopicArn' \
    --output text)

if [ $? -eq 0 ]; then
    echo "✅ SNSトピック作成完了: $SNS_TOPIC_ARN"
else
    echo "❌ SNSトピック作成エラー"
    exit 1
fi

# 2. CloudWatchアラーム - エラー数監視
echo "🚨 CloudWatchアラーム（エラー数）を作成中..."
if aws cloudwatch put-metric-alarm \
    --alarm-name "${FUNCTION_NAME}-errors" \
    --alarm-description "Lambda function ${FUNCTION_NAME} error monitoring" \
    --metric-name "Errors" \
    --namespace "AWS/Lambda" \
    --statistic "Sum" \
    --period 300 \
    --threshold 1 \
    --comparison-operator "GreaterThanOrEqualToThreshold" \
    --evaluation-periods 1 \
    --alarm-actions "$SNS_TOPIC_ARN" \
    --dimensions Name=FunctionName,Value="$FUNCTION_NAME" \
    --region "$AWS_REGION" > /dev/null; then
    echo "✅ エラー数アラーム作成完了"
else
    echo "❌ エラー数アラーム作成エラー"
fi

# 3. CloudWatchアラーム - タイムアウト監視
echo "⏱️  CloudWatchアラーム（タイムアウト）を作成中..."
if aws cloudwatch put-metric-alarm \
    --alarm-name "${FUNCTION_NAME}-timeouts" \
    --alarm-description "Lambda function ${FUNCTION_NAME} timeout monitoring" \
    --metric-name "Duration" \
    --namespace "AWS/Lambda" \
    --statistic "Maximum" \
    --period 300 \
    --threshold 290000 \
    --comparison-operator "GreaterThanThreshold" \
    --evaluation-periods 1 \
    --alarm-actions "$SNS_TOPIC_ARN" \
    --dimensions Name=FunctionName,Value="$FUNCTION_NAME" \
    --region "$AWS_REGION" > /dev/null; then
    echo "✅ タイムアウトアラーム作成完了"
else
    echo "❌ タイムアウトアラーム作成エラー"
fi

# 4. CloudWatchアラーム - スロットル監視
echo "🛑 CloudWatchアラーム（スロットル）を作成中..."
if aws cloudwatch put-metric-alarm \
    --alarm-name "${FUNCTION_NAME}-throttles" \
    --alarm-description "Lambda function ${FUNCTION_NAME} throttle monitoring" \
    --metric-name "Throttles" \
    --namespace "AWS/Lambda" \
    --statistic "Sum" \
    --period 300 \
    --threshold 1 \
    --comparison-operator "GreaterThanOrEqualToThreshold" \
    --evaluation-periods 1 \
    --alarm-actions "$SNS_TOPIC_ARN" \
    --dimensions Name=FunctionName,Value="$FUNCTION_NAME" \
    --region "$AWS_REGION" > /dev/null; then
    echo "✅ スロットルアラーム作成完了"
else
    echo "❌ スロットルアラーム作成エラー"
fi

echo ""
echo "🎉 CloudWatch監視設定完了！"
echo ""
echo "📋 作成されたアラーム:"
echo "1. ✅ ${FUNCTION_NAME}-errors (エラー数 >= 1)"
echo "2. ✅ ${FUNCTION_NAME}-timeouts (実行時間 > 290秒)"
echo "3. ✅ ${FUNCTION_NAME}-throttles (スロットル >= 1)"
echo ""
echo "📢 SNSトピック: $SNS_TOPIC_ARN"
echo ""
echo "💡 次の手順:"
echo "1. setup_slack_notifier.sh を実行してSlack通知機能を設定"
echo "2. テスト実行でアラーム動作を確認"
echo ""
echo "🔧 管理コマンド:"
echo "• アラーム一覧: aws cloudwatch describe-alarms --alarm-names ${FUNCTION_NAME}-errors ${FUNCTION_NAME}-timeouts ${FUNCTION_NAME}-throttles --region $AWS_REGION"
echo "• アラーム削除: aws cloudwatch delete-alarms --alarm-names ${FUNCTION_NAME}-errors --region $AWS_REGION"