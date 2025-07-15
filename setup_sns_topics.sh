#!/bin/bash

# SNSトピック作成・管理スクリプト
# エラー通知用のSNSトピックを作成し、各種通知先を設定

set -e

# 設定
AWS_REGION="ap-northeast-1"
SNS_ERROR_TOPIC="kabukan-error-alerts"
SNS_INFO_TOPIC="kabukan-info-notifications"
SLACK_LAMBDA_NAME="slack-notifier"

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

log_info "=== SNSトピック設定開始 ==="

# アカウントIDを取得
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

log_info "設定情報:"
log_info "  - リージョン: $AWS_REGION"
log_info "  - エラー通知トピック: $SNS_ERROR_TOPIC"
log_info "  - 情報通知トピック: $SNS_INFO_TOPIC"
log_info "  - Slack Lambda: $SLACK_LAMBDA_NAME"
log_info ""

# エラー通知用SNSトピック作成
create_error_topic() {
    log_info "1. エラー通知用SNSトピックを作成中..."
    
    SNS_ERROR_ARN=$(aws sns create-topic \
        --name "$SNS_ERROR_TOPIC" \
        --region "$AWS_REGION" \
        --query 'TopicArn' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$SNS_ERROR_ARN" ]] && [[ "$SNS_ERROR_ARN" != "None" ]]; then
        log_info "✅ エラー通知SNSトピック作成完了: $SNS_ERROR_ARN"
        
        # トピック属性を設定（表示名）
        aws sns set-topic-attributes \
            --topic-arn "$SNS_ERROR_ARN" \
            --attribute-name "DisplayName" \
            --attribute-value "Kabukan Error Alerts" \
            --region "$AWS_REGION" > /dev/null
        
        log_info "✅ エラートピック属性設定完了"
    else
        log_error "❌ エラー通知SNSトピック作成失敗"
        return 1
    fi
}

# 情報通知用SNSトピック作成
create_info_topic() {
    log_info "2. 情報通知用SNSトピックを作成中..."
    
    SNS_INFO_ARN=$(aws sns create-topic \
        --name "$SNS_INFO_TOPIC" \
        --region "$AWS_REGION" \
        --query 'TopicArn' \
        --output text 2>/dev/null || echo "")
    
    if [[ -n "$SNS_INFO_ARN" ]] && [[ "$SNS_INFO_ARN" != "None" ]]; then
        log_info "✅ 情報通知SNSトピック作成完了: $SNS_INFO_ARN"
        
        # トピック属性を設定（表示名）
        aws sns set-topic-attributes \
            --topic-arn "$SNS_INFO_ARN" \
            --attribute-name "DisplayName" \
            --attribute-value "Kabukan Info Notifications" \
            --region "$AWS_REGION" > /dev/null
        
        log_info "✅ 情報トピック属性設定完了"
    else
        log_error "❌ 情報通知SNSトピック作成失敗"
        return 1
    fi
}

# Slack Lambda関数をSNSにサブスクライブ
subscribe_slack_lambda() {
    log_info "3. Slack Lambda関数をSNSにサブスクライブ中..."
    
    # Slack Lambda関数の存在確認
    SLACK_LAMBDA_ARN="arn:aws:lambda:$AWS_REGION:$ACCOUNT_ID:function:$SLACK_LAMBDA_NAME"
    
    if aws lambda get-function --function-name "$SLACK_LAMBDA_NAME" --region "$AWS_REGION" &>/dev/null; then
        # エラートピックにサブスクライブ
        if [[ -n "$SNS_ERROR_ARN" ]]; then
            SUBSCRIPTION_ARN=$(aws sns subscribe \
                --topic-arn "$SNS_ERROR_ARN" \
                --protocol "lambda" \
                --notification-endpoint "$SLACK_LAMBDA_ARN" \
                --region "$AWS_REGION" \
                --query 'SubscriptionArn' \
                --output text 2>/dev/null || echo "")
            
            if [[ -n "$SUBSCRIPTION_ARN" ]] && [[ "$SUBSCRIPTION_ARN" != "None" ]]; then
                log_info "✅ エラートピックへのSlack Lambda サブスクリプション完了"
            else
                log_warn "⚠️  エラートピックへのサブスクリプション失敗（既に存在する可能性）"
            fi
        fi
        
        # 情報トピックにサブスクライブ
        if [[ -n "$SNS_INFO_ARN" ]]; then
            SUBSCRIPTION_ARN=$(aws sns subscribe \
                --topic-arn "$SNS_INFO_ARN" \
                --protocol "lambda" \
                --notification-endpoint "$SLACK_LAMBDA_ARN" \
                --region "$AWS_REGION" \
                --query 'SubscriptionArn' \
                --output text 2>/dev/null || echo "")
            
            if [[ -n "$SUBSCRIPTION_ARN" ]] && [[ "$SUBSCRIPTION_ARN" != "None" ]]; then
                log_info "✅ 情報トピックへのSlack Lambda サブスクリプション完了"
            else
                log_warn "⚠️  情報トピックへのサブスクリプション失敗（既に存在する可能性）"
            fi
        fi
        
        # Lambda実行権限を追加
        STATEMENT_ID="sns-invoke-$(date +%s)"
        aws lambda add-permission \
            --function-name "$SLACK_LAMBDA_NAME" \
            --statement-id "$STATEMENT_ID" \
            --action "lambda:InvokeFunction" \
            --principal "sns.amazonaws.com" \
            --source-arn "$SNS_ERROR_ARN" \
            --region "$AWS_REGION" > /dev/null 2>&1 || log_warn "⚠️  Lambda実行権限追加でエラー（既に存在する可能性）"
        
        log_info "✅ Slack Lambda実行権限設定完了"
    else
        log_warn "⚠️  Slack Lambda関数が見つかりません。先にデプロイしてください。"
    fi
}

# Emailサブスクリプションのオプション設定
setup_email_subscription() {
    if [[ -n "$EMAIL_ADDRESS" ]]; then
        log_info "4. Email通知を設定中..."
        
        if [[ -n "$SNS_ERROR_ARN" ]]; then
            aws sns subscribe \
                --topic-arn "$SNS_ERROR_ARN" \
                --protocol "email" \
                --notification-endpoint "$EMAIL_ADDRESS" \
                --region "$AWS_REGION" > /dev/null
            
            log_info "✅ Emailサブスクリプション作成完了: $EMAIL_ADDRESS"
            log_warn "⚠️  Email確認リンクをクリックしてサブスクリプションを有効化してください"
        fi
    else
        log_info "4. Email通知設定をスキップ（EMAIL_ADDRESS未設定）"
    fi
}

# SNSトピックの確認
verify_topics() {
    log_info "5. SNSトピック設定を確認中..."
    
    log_info ""
    log_info "SNSトピック一覧:"
    aws sns list-topics --region "$AWS_REGION" --query "Topics[?contains(TopicArn, 'kabukan')].TopicArn" --output table
    
    if [[ -n "$SNS_ERROR_ARN" ]]; then
        log_info ""
        log_info "エラートピックのサブスクリプション:"
        aws sns list-subscriptions-by-topic \
            --topic-arn "$SNS_ERROR_ARN" \
            --region "$AWS_REGION" \
            --query 'Subscriptions[*].{Protocol:Protocol,Endpoint:Endpoint,SubscriptionArn:SubscriptionArn}' \
            --output table 2>/dev/null || log_warn "サブスクリプション取得失敗"
    fi
}

# 使用方法
echo "使用方法:"
echo "  ./setup_sns_topics.sh [error|info|all]"
echo "  EMAIL_ADDRESS=your@email.com ./setup_sns_topics.sh all  # Email通知も設定"
echo ""

if [[ $# -eq 0 ]] || [[ "$1" == "all" ]]; then
    log_info "全てのSNSトピックを設定します..."
    create_error_topic
    create_info_topic
    subscribe_slack_lambda
    setup_email_subscription
    verify_topics
elif [[ "$1" == "error" ]]; then
    create_error_topic
    subscribe_slack_lambda
    verify_topics
elif [[ "$1" == "info" ]]; then
    create_info_topic
    subscribe_slack_lambda
    verify_topics
else
    log_error "無効なオプション: $1"
    log_info "使用可能なオプション: error, info, all"
    exit 1
fi

log_info ""
log_info "🎉 SNSトピック設定完了！"
log_info ""
log_info "📋 設定内容:"
log_info "1. ✅ エラー通知トピック: $SNS_ERROR_TOPIC"
log_info "2. ✅ 情報通知トピック: $SNS_INFO_TOPIC"
log_info "3. ✅ Slack Lambda サブスクリプション設定"
if [[ -n "$EMAIL_ADDRESS" ]]; then
    log_info "4. ✅ Email通知設定: $EMAIL_ADDRESS"
fi
log_info ""
log_info "📋 作成されたARN:"
if [[ -n "$SNS_ERROR_ARN" ]]; then
    log_info "• エラートピック: $SNS_ERROR_ARN"
fi
if [[ -n "$SNS_INFO_ARN" ]]; then
    log_info "• 情報トピック: $SNS_INFO_ARN"
fi
log_info ""
log_info "💡 次のステップ:"
log_info "1. ./setup_cloudwatch_alarms.sh でCloudWatchアラーム設定"
log_info "2. テスト通知の送信:"
log_info "   aws sns publish --topic-arn '$SNS_ERROR_ARN' --message 'テストメッセージ' --region $AWS_REGION"
log_info ""
log_info "🔧 管理コマンド:"
log_info "• トピック削除: aws sns delete-topic --topic-arn [TOPIC_ARN] --region $AWS_REGION"
log_info "• サブスクリプション解除: aws sns unsubscribe --subscription-arn [SUBSCRIPTION_ARN] --region $AWS_REGION"