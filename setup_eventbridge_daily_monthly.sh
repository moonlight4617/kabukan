#!/bin/bash

# EventBridge日次・月次実行設定スクリプト
# 日次: 売買タイミングアドバイス (平日 9:00 JST)
# 月次: ポートフォリオ分析 (毎月1日 9:00 JST)

set -e

FUNCTION_NAME="kabukan"
AWS_REGION="ap-northeast-1"
DAILY_RULE_NAME="kabukan-daily-execution"
MONTHLY_RULE_NAME="kabukan-monthly-execution"

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

log_info "=== EventBridge 日次・月次スケジュール設定中 ==="

# アカウントIDを取得
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LAMBDA_ARN="arn:aws:lambda:$AWS_REGION:$ACCOUNT_ID:function:$FUNCTION_NAME"

log_info "設定情報:"
log_info "  - Lambda関数: $FUNCTION_NAME"
log_info "  - リージョン: $AWS_REGION"
log_info "  - 日次実行: 平日 9:00 JST (UTC 0:00)"
log_info "  - 月次実行: 毎月1日 9:00 JST (UTC 0:00)"
log_info ""

# 日次実行ルールの設定
setup_daily_rule() {
    log_info "1. 日次実行ルールを設定中..."
    
    # EventBridgeルールを作成
    if aws events put-rule \
        --name "$DAILY_RULE_NAME" \
        --schedule-expression "cron(0 0 ? * MON-FRI *)" \
        --description "Daily execution for trading timing advice" \
        --state ENABLED \
        --region "$AWS_REGION" > /dev/null; then
        log_info "✅ 日次EventBridgeルールの作成完了"
    else
        log_error "❌ 日次EventBridgeルールの作成エラー"
        return 1
    fi
    
    # Lambda関数に実行権限を追加
    DAILY_STATEMENT_ID="eventbridge-daily-$(date +%s)"
    if aws lambda add-permission \
        --function-name "$FUNCTION_NAME" \
        --statement-id "$DAILY_STATEMENT_ID" \
        --action "lambda:InvokeFunction" \
        --principal "events.amazonaws.com" \
        --source-arn "arn:aws:events:$AWS_REGION:$ACCOUNT_ID:rule/$DAILY_RULE_NAME" \
        --region "$AWS_REGION" > /dev/null 2>&1; then
        log_info "✅ 日次Lambda実行権限の追加完了"
    else
        log_warn "⚠️  日次Lambda実行権限の追加でエラー（既に存在する可能性があります）"
    fi
    
    # ターゲットを設定（execution_type: daily）
    if aws events put-targets \
        --rule "$DAILY_RULE_NAME" \
        --targets "Id=1,Arn=$LAMBDA_ARN,Input={\"execution_type\":\"daily\"}" \
        --region "$AWS_REGION" > /dev/null; then
        log_info "✅ 日次ターゲット設定完了"
    else
        log_error "❌ 日次ターゲット設定エラー"
        return 1
    fi
}

# 月次実行ルールの設定
setup_monthly_rule() {
    log_info "2. 月次実行ルールを設定中..."
    
    # EventBridgeルールを作成
    if aws events put-rule \
        --name "$MONTHLY_RULE_NAME" \
        --schedule-expression "cron(0 0 1 * ? *)" \
        --description "Monthly execution for portfolio analysis" \
        --state ENABLED \
        --region "$AWS_REGION" > /dev/null; then
        log_info "✅ 月次EventBridgeルールの作成完了"
    else
        log_error "❌ 月次EventBridgeルールの作成エラー"
        return 1
    fi
    
    # Lambda関数に実行権限を追加
    MONTHLY_STATEMENT_ID="eventbridge-monthly-$(date +%s)"
    if aws lambda add-permission \
        --function-name "$FUNCTION_NAME" \
        --statement-id "$MONTHLY_STATEMENT_ID" \
        --action "lambda:InvokeFunction" \
        --principal "events.amazonaws.com" \
        --source-arn "arn:aws:events:$AWS_REGION:$ACCOUNT_ID:rule/$MONTHLY_RULE_NAME" \
        --region "$AWS_REGION" > /dev/null 2>&1; then
        log_info "✅ 月次Lambda実行権限の追加完了"
    else
        log_warn "⚠️  月次Lambda実行権限の追加でエラー（既に存在する可能性があります）"
    fi
    
    # ターゲットを設定（execution_type: monthly）
    if aws events put-targets \
        --rule "$MONTHLY_RULE_NAME" \
        --targets "Id=1,Arn=$LAMBDA_ARN,Input={\"execution_type\":\"monthly\"}" \
        --region "$AWS_REGION" > /dev/null; then
        log_info "✅ 月次ターゲット設定完了"
    else
        log_error "❌ 月次ターゲット設定エラー"
        return 1
    fi
}

# 設定確認
verify_setup() {
    log_info "3. 設定確認中..."
    
    log_info ""
    log_info "EventBridgeルール詳細:"
    aws events describe-rule \
        --name "$DAILY_RULE_NAME" \
        --region "$AWS_REGION" \
        --query '{Name:Name,State:State,ScheduleExpression:ScheduleExpression,Description:Description}' \
        --output table 2>/dev/null || log_warn "日次ルールの詳細取得に失敗"
    
    aws events describe-rule \
        --name "$MONTHLY_RULE_NAME" \
        --region "$AWS_REGION" \
        --query '{Name:Name,State:State,ScheduleExpression:ScheduleExpression,Description:Description}' \
        --output table 2>/dev/null || log_warn "月次ルールの詳細取得に失敗"
    
    log_info ""
    log_info "日次ターゲット設定:"
    aws events list-targets-by-rule \
        --rule "$DAILY_RULE_NAME" \
        --region "$AWS_REGION" \
        --query 'Targets[*].{Id:Id,Arn:Arn,Input:Input}' \
        --output table 2>/dev/null || log_warn "日次ターゲットの詳細取得に失敗"
    
    log_info ""
    log_info "月次ターゲット設定:"
    aws events list-targets-by-rule \
        --rule "$MONTHLY_RULE_NAME" \
        --region "$AWS_REGION" \
        --query 'Targets[*].{Id:Id,Arn:Arn,Input:Input}' \
        --output table 2>/dev/null || log_warn "月次ターゲットの詳細取得に失敗"
}

# 使用方法
echo "使用方法:"
echo "  ./setup_eventbridge_daily_monthly.sh [daily|monthly|all]"
echo ""

if [[ $# -eq 0 ]] || [[ "$1" == "all" ]]; then
    log_info "日次・月次の両方のスケジュールを設定します..."
    setup_daily_rule
    setup_monthly_rule
    verify_setup
elif [[ "$1" == "daily" ]]; then
    setup_daily_rule
    verify_setup
elif [[ "$1" == "monthly" ]]; then
    setup_monthly_rule
    verify_setup
else
    log_error "無効なオプション: $1"
    log_info "使用可能なオプション: daily, monthly, all"
    exit 1
fi

log_info ""
log_info "🎉 EventBridge スケジュール設定完了！"
log_info ""
log_info "📋 設定内容:"
log_info "1. ✅ 日次実行: 平日 9:00 JST (売買タイミングアドバイス)"
log_info "2. ✅ 月次実行: 毎月1日 9:00 JST (ポートフォリオ分析)"
log_info "3. スケジュール変更: SCHEDULE_EXPRESSIONを編集してスクリプト再実行"
log_info "  • 実行間隔例:"
log_info "  - rate(5 minutes) : 5分毎"
log_info "  - rate(1 hour)    : 1時間毎"
log_info "  - rate(1 day)     : 1日毎"
log_info "  - cron(0 9 * * ? *) : 毎日9時（UTC）"
log_info ""
log_info "💡 手動テスト用コマンド:"
log_info "• 日次実行テスト:"
log_info "  aws lambda invoke --function-name $FUNCTION_NAME --payload '{\"execution_type\":\"daily\"}' response.json --region $AWS_REGION"
log_info ""
log_info "• 月次実行テスト:"
log_info "  aws lambda invoke --function-name $FUNCTION_NAME --payload '{\"execution_type\":\"monthly\"}' response.json --region $AWS_REGION"
log_info ""
log_info "🔧 管理コマンド:"
log_info "• 日次ルール無効化: aws events disable-rule --name $DAILY_RULE_NAME --region $AWS_REGION"
log_info "• 月次ルール無効化: aws events disable-rule --name $MONTHLY_RULE_NAME --region $AWS_REGION"
log_info "• ルール削除: aws events delete-rule --name [RULE_NAME] --region $AWS_REGION"