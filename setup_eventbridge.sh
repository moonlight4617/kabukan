#!/bin/bash
# EventBridge定期実行設定スクリプト

FUNCTION_NAME="kabukan"
AWS_REGION="ap-northeast-1"
RULE_NAME="kabukan-schedule-rule"
SCHEDULE_EXPRESSION="rate(1 hour)"  # 1時間毎に実行（変更可能）

echo "⏰ EventBridge定期実行を設定中..."

# アカウントIDを取得
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LAMBDA_ARN="arn:aws:lambda:$AWS_REGION:$ACCOUNT_ID:function:$FUNCTION_NAME"

echo "📋 設定情報:"
echo "  - Lambda関数: $FUNCTION_NAME"
echo "  - リージョン: $AWS_REGION"
echo "  - 実行間隔: $SCHEDULE_EXPRESSION"
echo "  - ルール名: $RULE_NAME"
echo ""

# 1. EventBridgeルールを作成
echo "📅 EventBridgeスケジュールルールを作成中..."
if aws events put-rule \
    --name "$RULE_NAME" \
    --schedule-expression "$SCHEDULE_EXPRESSION" \
    --description "Kabukan Lambda function scheduled execution" \
    --state ENABLED \
    --region "$AWS_REGION" > /dev/null; then
    echo "✅ EventBridgeルールの作成完了"
else
    echo "❌ EventBridgeルールの作成エラー"
    exit 1
fi

# 2. Lambda関数にEventBridge実行権限を追加
echo "🔐 Lambda関数にEventBridge実行権限を追加中..."
STATEMENT_ID="eventbridge-$RULE_NAME-$(date +%s)"

if aws lambda add-permission \
    --function-name "$FUNCTION_NAME" \
    --statement-id "$STATEMENT_ID" \
    --action "lambda:InvokeFunction" \
    --principal "events.amazonaws.com" \
    --source-arn "arn:aws:events:$AWS_REGION:$ACCOUNT_ID:rule/$RULE_NAME" \
    --region "$AWS_REGION" > /dev/null; then
    echo "✅ Lambda実行権限の追加完了"
else
    echo "⚠️  Lambda実行権限の追加でエラー（既に存在する可能性があります）"
fi

# 3. EventBridgeルールにLambda関数をターゲットとして追加
echo "🎯 EventBridgeルールにLambda関数をターゲットとして追加中..."
TARGETS_JSON=$(cat <<EOF
[
    {
        "Id": "1",
        "Arn": "$LAMBDA_ARN"
    }
]
EOF
)

if aws events put-targets \
    --rule "$RULE_NAME" \
    --targets "$TARGETS_JSON" \
    --region "$AWS_REGION" > /dev/null; then
    echo "✅ ターゲットの追加完了"
else
    echo "❌ ターゲットの追加エラー"
    exit 1
fi

# 4. 設定確認
echo "🔍 設定確認中..."
echo ""
echo "EventBridgeルール詳細:"
aws events describe-rule \
    --name "$RULE_NAME" \
    --region "$AWS_REGION" \
    --query '{Name:Name,State:State,ScheduleExpression:ScheduleExpression,Description:Description}' \
    --output table

echo ""
echo "ターゲット設定:"
aws events list-targets-by-rule \
    --rule "$RULE_NAME" \
    --region "$AWS_REGION" \
    --query 'Targets[*].{Id:Id,Arn:Arn}' \
    --output table

echo ""
echo "🎉 EventBridge定期実行設定完了！"
echo ""
echo "📋 設定内容:"
echo "1. ✅ EventBridgeルール作成: $RULE_NAME"
echo "2. ✅ 実行スケジュール: $SCHEDULE_EXPRESSION"
echo "3. ✅ Lambda実行権限追加"
echo "4. ✅ ターゲット設定完了"
echo ""
echo "💡 使用方法:"
echo "• スケジュール変更: SCHEDULE_EXPRESSIONを編集してスクリプト再実行"
echo "• 実行間隔例:"
echo "  - rate(5 minutes) : 5分毎"
echo "  - rate(1 hour)    : 1時間毎"
echo "  - rate(1 day)     : 1日毎"
echo "  - cron(0 9 * * ? *) : 毎日9時（UTC）"
echo ""
echo "🔧 管理コマンド:"
echo "• ルール無効化: aws events disable-rule --name $RULE_NAME --region $AWS_REGION"
echo "• ルール有効化: aws events enable-rule --name $RULE_NAME --region $AWS_REGION"
echo "• ルール削除: aws events delete-rule --name $RULE_NAME --region $AWS_REGION"