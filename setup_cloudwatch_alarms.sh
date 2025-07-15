#!/bin/bash

# CloudWatchアラーム専用設定スクリプト
# Lambda関数のエラー、タイムアウト、スロットルを監視

set -e

# 設定
AWS_REGION="ap-northeast-1"
LAMBDA_FUNCTION_NAME="kabukan"
SLACK_LAMBDA_FUNCTION_NAME="slack-notifier"
SNS_ERROR_TOPIC="kabukan-error-alerts"

# 色付きログ関数
log_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

log_warn() {
    echo -e "\033[0;33m[WARN]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# エラーハンドリング
error_exit() {
    log_error "$1"
    exit 1
}

log_info "=== CloudWatchアラーム設定開始 ==="

# アカウントIDを取得
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
SNS_TOPIC_ARN="arn:aws:sns:$AWS_REGION:$ACCOUNT_ID:$SNS_ERROR_TOPIC"

log_info "設定情報:"
log_info "  - 監視対象Lambda: $LAMBDA_FUNCTION_NAME"
log_info "  - Slack通知Lambda: $SLACK_LAMBDA_FUNCTION_NAME"
log_info "  - リージョン: $AWS_REGION"
log_info "  - SNSトピック: $SNS_TOPIC_ARN"
log_info ""

# SNSトピックの存在確認
check_sns_topic() {
    if aws sns get-topic-attributes --topic-arn "$SNS_TOPIC_ARN" --region "$AWS_REGION" &>/dev/null; then
        log_info "✅ SNSトピック確認完了"
    else
        log_warn "⚠️  SNSトピックが見つかりません。先に ./setup_sns_topics.sh を実行してください"
        return 1
    fi
}

# メインLambda関数のアラーム設定
setup_main_lambda_alarms() {
    log_info "1. メインLambda関数のアラームを設定中..."
    
    # エラー数監視アラーム
    log_info "エラー数監視アラームを作成中..."
    aws cloudwatch put-metric-alarm \
        --alarm-name "${LAMBDA_FUNCTION_NAME}-errors" \
        --alarm-description "Lambda function ${LAMBDA_FUNCTION_NAME} error count monitoring" \
        --metric-name "Errors" \
        --namespace "AWS/Lambda" \
        --statistic "Sum" \
        --period 300 \
        --threshold 1 \
        --comparison-operator "GreaterThanOrEqualToThreshold" \
        --evaluation-periods 1 \
        --alarm-actions "$SNS_TOPIC_ARN" \
        --ok-actions "$SNS_TOPIC_ARN" \
        --dimensions Name=FunctionName,Value="$LAMBDA_FUNCTION_NAME" \
        --region "$AWS_REGION" > /dev/null
    
    log_info "✅ エラー数アラーム作成完了"
    
    # タイムアウト監視アラーム（290秒でアラート、300秒がタイムアウト）
    log_info "タイムアウト監視アラームを作成中..."
    aws cloudwatch put-metric-alarm \
        --alarm-name "${LAMBDA_FUNCTION_NAME}-timeouts" \
        --alarm-description "Lambda function ${LAMBDA_FUNCTION_NAME} timeout monitoring" \
        --metric-name "Duration" \
        --namespace "AWS/Lambda" \
        --statistic "Maximum" \
        --period 300 \
        --threshold 290000 \
        --comparison-operator "GreaterThanThreshold" \
        --evaluation-periods 1 \
        --alarm-actions "$SNS_TOPIC_ARN" \
        --ok-actions "$SNS_TOPIC_ARN" \
        --dimensions Name=FunctionName,Value="$LAMBDA_FUNCTION_NAME" \
        --region "$AWS_REGION" > /dev/null
    
    log_info "✅ タイムアウトアラーム作成完了"
    
    # スロットル監視アラーム
    log_info "スロットル監視アラームを作成中..."
    aws cloudwatch put-metric-alarm \
        --alarm-name "${LAMBDA_FUNCTION_NAME}-throttles" \
        --alarm-description "Lambda function ${LAMBDA_FUNCTION_NAME} throttle monitoring" \
        --metric-name "Throttles" \
        --namespace "AWS/Lambda" \
        --statistic "Sum" \
        --period 300 \
        --threshold 1 \
        --comparison-operator "GreaterThanOrEqualToThreshold" \
        --evaluation-periods 1 \
        --alarm-actions "$SNS_TOPIC_ARN" \
        --ok-actions "$SNS_TOPIC_ARN" \
        --dimensions Name=FunctionName,Value="$LAMBDA_FUNCTION_NAME" \
        --region "$AWS_REGION" > /dev/null
    
    log_info "✅ スロットルアラーム作成完了"
    
    # 実行回数監視アラーム（異常な頻度実行を検知）
    log_info "実行回数監視アラームを作成中..."
    aws cloudwatch put-metric-alarm \
        --alarm-name "${LAMBDA_FUNCTION_NAME}-invocations-high" \
        --alarm-description "Lambda function ${LAMBDA_FUNCTION_NAME} high invocation rate monitoring" \
        --metric-name "Invocations" \
        --namespace "AWS/Lambda" \
        --statistic "Sum" \
        --period 3600 \
        --threshold 50 \
        --comparison-operator "GreaterThanThreshold" \
        --evaluation-periods 1 \
        --alarm-actions "$SNS_TOPIC_ARN" \
        --dimensions Name=FunctionName,Value="$LAMBDA_FUNCTION_NAME" \
        --region "$AWS_REGION" > /dev/null
    
    log_info "✅ 実行回数アラーム作成完了"
}

# Slack Lambda関数のアラーム設定
setup_slack_lambda_alarms() {
    log_info "2. Slack Lambda関数のアラームを設定中..."
    
    # Slack Lambda関数の存在確認
    if aws lambda get-function --function-name "$SLACK_LAMBDA_FUNCTION_NAME" --region "$AWS_REGION" &>/dev/null; then
        # エラー数監視アラーム
        log_info "Slack Lambdaエラー数監視アラームを作成中..."
        aws cloudwatch put-metric-alarm \
            --alarm-name "${SLACK_LAMBDA_FUNCTION_NAME}-errors" \
            --alarm-description "Slack notification Lambda ${SLACK_LAMBDA_FUNCTION_NAME} error monitoring" \
            --metric-name "Errors" \
            --namespace "AWS/Lambda" \
            --statistic "Sum" \
            --period 300 \
            --threshold 1 \
            --comparison-operator "GreaterThanOrEqualToThreshold" \
            --evaluation-periods 1 \
            --alarm-actions "$SNS_TOPIC_ARN" \
            --dimensions Name=FunctionName,Value="$SLACK_LAMBDA_FUNCTION_NAME" \
            --region "$AWS_REGION" > /dev/null
        
        log_info "✅ Slack Lambdaエラーアラーム作成完了"
        
        # タイムアウト監視アラーム（55秒でアラート、60秒がタイムアウト）
        log_info "Slack Lambdaタイムアウト監視アラームを作成中..."
        aws cloudwatch put-metric-alarm \
            --alarm-name "${SLACK_LAMBDA_FUNCTION_NAME}-timeouts" \
            --alarm-description "Slack notification Lambda ${SLACK_LAMBDA_FUNCTION_NAME} timeout monitoring" \
            --metric-name "Duration" \
            --namespace "AWS/Lambda" \
            --statistic "Maximum" \
            --period 300 \
            --threshold 55000 \
            --comparison-operator "GreaterThanThreshold" \
            --evaluation-periods 1 \
            --alarm-actions "$SNS_TOPIC_ARN" \
            --dimensions Name=FunctionName,Value="$SLACK_LAMBDA_FUNCTION_NAME" \
            --region "$AWS_REGION" > /dev/null
        
        log_info "✅ Slack Lambdaタイムアウトアラーム作成完了"
    else
        log_warn "⚠️  Slack Lambda関数が見つかりません。スキップします。"
    fi
}

# EventBridgeルールの失敗監視
setup_eventbridge_alarms() {
    log_info "3. EventBridgeルールの監視アラームを設定中..."
    
    # EventBridge失敗監視
    log_info "EventBridge失敗監視アラームを作成中..."
    aws cloudwatch put-metric-alarm \
        --alarm-name "kabukan-eventbridge-failures" \
        --alarm-description "EventBridge rule failures for kabukan schedules" \
        --metric-name "FailedInvocations" \
        --namespace "AWS/Events" \
        --statistic "Sum" \
        --period 300 \
        --threshold 1 \
        --comparison-operator "GreaterThanOrEqualToThreshold" \
        --evaluation-periods 1 \
        --alarm-actions "$SNS_TOPIC_ARN" \
        --region "$AWS_REGION" > /dev/null 2>&1 || log_warn "⚠️  EventBridgeアラーム作成でエラー（メトリクスが存在しない可能性）"
    
    log_info "✅ EventBridgeアラーム作成完了"
}

# アラーム設定の確認
verify_alarms() {
    log_info "4. 作成されたアラームを確認中..."
    
    log_info ""
    log_info "作成されたCloudWatchアラーム:"
    aws cloudwatch describe-alarms \
        --alarm-name-prefix "kabukan" \
        --region "$AWS_REGION" \
        --query 'MetricAlarms[*].{AlarmName:AlarmName,StateValue:StateValue,MetricName:MetricName,Threshold:Threshold}' \
        --output table 2>/dev/null || log_warn "アラーム一覧取得失敗"
    
    log_info ""
    log_info "Slack通知Lambda関連アラーム:"
    aws cloudwatch describe-alarms \
        --alarm-name-prefix "$SLACK_LAMBDA_FUNCTION_NAME" \
        --region "$AWS_REGION" \
        --query 'MetricAlarms[*].{AlarmName:AlarmName,StateValue:StateValue,MetricName:MetricName,Threshold:Threshold}' \
        --output table 2>/dev/null || log_warn "Slack Lambdaアラーム一覧取得失敗"
}

# テストアラーム発動
test_alarm() {
    log_info "5. アラームテストを実行中..."
    
    log_warn "⚠️  テストのため一時的にアラーム状態を変更します"
    aws cloudwatch set-alarm-state \
        --alarm-name "${LAMBDA_FUNCTION_NAME}-errors" \
        --state-value "ALARM" \
        --state-reason "テスト実行によるアラーム状態変更" \
        --region "$AWS_REGION" 2>/dev/null || log_warn "テストアラーム設定失敗"
    
    log_info "✅ テストアラーム実行完了（Slack通知を確認してください）"
    
    # 5秒後に正常状態に戻す
    sleep 5
    aws cloudwatch set-alarm-state \
        --alarm-name "${LAMBDA_FUNCTION_NAME}-errors" \
        --state-value "OK" \
        --state-reason "テスト完了" \
        --region "$AWS_REGION" 2>/dev/null || log_warn "アラーム正常化失敗"
    
    log_info "✅ テストアラーム正常化完了"
}

# 使用方法
echo "使用方法:"
echo "  ./setup_cloudwatch_alarms.sh [main|slack|eventbridge|all|test]"
echo ""

if [[ $# -eq 0 ]] || [[ "$1" == "all" ]]; then
    log_info "全てのCloudWatchアラームを設定します..."
    check_sns_topic || exit 1
    setup_main_lambda_alarms
    setup_slack_lambda_alarms
    setup_eventbridge_alarms
    verify_alarms
elif [[ "$1" == "main" ]]; then
    check_sns_topic || exit 1
    setup_main_lambda_alarms
    verify_alarms
elif [[ "$1" == "slack" ]]; then
    check_sns_topic || exit 1
    setup_slack_lambda_alarms
    verify_alarms
elif [[ "$1" == "eventbridge" ]]; then
    check_sns_topic || exit 1
    setup_eventbridge_alarms
    verify_alarms
elif [[ "$1" == "test" ]]; then
    test_alarm
else
    log_error "無効なオプション: $1"
    log_info "使用可能なオプション: main, slack, eventbridge, all, test"
    exit 1
fi

log_info ""
log_info "🎉 CloudWatchアラーム設定完了！"
log_info ""
log_info "📋 設定内容:"
log_info "1. ✅ メインLambda監視: エラー、タイムアウト、スロットル、実行回数"
log_info "2. ✅ Slack Lambda監視: エラー、タイムアウト"
log_info "3. ✅ EventBridge監視: 失敗した実行"
log_info "4. ✅ SNS通知設定: $SNS_TOPIC_ARN"
log_info ""
log_info "💡 アラーム閾値:"
log_info "• エラー数: >= 1回（5分間）"
log_info "• タイムアウト: > 290秒（メインLambda）、> 55秒（Slack Lambda）"
log_info "• スロットル: >= 1回（5分間）"
log_info "• 実行回数: > 50回（1時間）"
log_info ""
log_info "🔧 管理コマンド:"
log_info "• アラーム一覧: aws cloudwatch describe-alarms --alarm-name-prefix kabukan --region $AWS_REGION"
log_info "• アラーム削除: aws cloudwatch delete-alarms --alarm-names [ALARM_NAME] --region $AWS_REGION"
log_info "• テスト実行: ./setup_cloudwatch_alarms.sh test"