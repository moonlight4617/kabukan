#!/bin/bash

# Lambda関数デプロイスクリプト
# メインのkabukan関数とSlack通知関数をデプロイ

set -e

# 設定
REGION="ap-northeast-1"
LAMBDA_FUNCTION_NAME="kabukan"
SLACK_LAMBDA_FUNCTION_NAME="slack-notifier"
BUCKET_NAME="kabukan-credentials-bucket"

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

# AWS CLIの確認
if ! command -v aws &> /dev/null; then
    error_exit "AWS CLIがインストールされていません"
fi

# メインLambda関数のデプロイ
deploy_main_lambda() {
    log_info "=== メインLambda関数 ($LAMBDA_FUNCTION_NAME) をデプロイ中 ==="
    
    # 必要ファイルの確認
    if [[ ! -f "lambda_main.py" ]] || [[ ! -f "requirements_lambda_main.txt" ]]; then
        error_exit "lambda_main.pyまたはrequirements_lambda_main.txtが見つかりません"
    fi
    
    # パッケージ作成
    log_info "Lambdaパッケージを作成中..."
    mkdir -p temp_lambda
    
    # Pythonファイルをコピー
    cp *.py temp_lambda/ 2>/dev/null || log_warn "一部の*.pyファイルが見つかりません"
    
    # credentials_configディレクトリをコピー（存在する場合）
    if [[ -d "credentials_config" ]]; then
        cp -r credentials_config temp_lambda/
        log_info "credentials_configディレクトリをコピーしました"
    fi
    
    cd temp_lambda
    
    # 依存関係をインストール
    log_info "依存関係をインストール中..."
    pip install -r ../requirements_lambda_main.txt -t . --quiet
    
    # ZIPファイル作成
    log_info "ZIPファイルを作成中..."
    zip -r ../lambda_deploy.zip . > /dev/null
    
    cd ..
    rm -rf temp_lambda
    
    # Lambda関数の存在確認とデプロイ
    if aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME --region $REGION &>/dev/null; then
        log_info "既存のLambda関数を更新中..."
        aws lambda update-function-code \
            --function-name $LAMBDA_FUNCTION_NAME \
            --zip-file fileb://lambda_deploy.zip \
            --region $REGION > /dev/null
        
        log_info "Lambda関数の設定を更新中..."
        aws lambda update-function-configuration \
            --function-name $LAMBDA_FUNCTION_NAME \
            --runtime python3.9 \
            --timeout 300 \
            --memory-size 512 \
            --environment Variables="{GOOGLE_SHEETS_CREDENTIALS_PATH=s3://$BUCKET_NAME/credentials.json,GOOGLE_API_KEY=$GOOGLE_API_KEY,SLACK_BOT_TOKEN=$SLACK_BOT_TOKEN,SLACK_CHANNEL_ID=$SLACK_CHANNEL_ID}" \
            --region $REGION > /dev/null
        
        log_info "✅ 既存Lambda関数の更新完了"
    else
        log_info "新しいLambda関数を作成中..."
        aws lambda create-function \
            --function-name $LAMBDA_FUNCTION_NAME \
            --runtime python3.9 \
            --role arn:aws:iam::502674413540:role/lambda-execution-role \
            --handler lambda_main.lambda_handler \
            --zip-file fileb://lambda_deploy.zip \
            --timeout 300 \
            --memory-size 512 \
            --environment Variables="{GOOGLE_SHEETS_CREDENTIALS_PATH=s3://$BUCKET_NAME/credentials.json,GOOGLE_API_KEY=$GOOGLE_API_KEY,SLACK_BOT_TOKEN=$SLACK_BOT_TOKEN,SLACK_CHANNEL_ID=$SLACK_CHANNEL_ID}" \
            --region $REGION > /dev/null
        
        log_info "✅ 新しいLambda関数の作成完了"
    fi
    
    rm lambda_deploy.zip
}

# Layerアタッチ
attach_layers() {
    log_info "=== Lambda Layersをアタッチ中 ==="
    
    # 最新のLayer ARNを取得
    SCRAPING_LAYER_ARN=$(aws lambda list-layer-versions --layer-name kabukan-layer-scraping --region $REGION --query 'LayerVersions[0].LayerVersionArn' --output text 2>/dev/null || echo "")
    WEB_LAYER_ARN=$(aws lambda list-layer-versions --layer-name kabukan-layer-web --region $REGION --query 'LayerVersions[0].LayerVersionArn' --output text 2>/dev/null || echo "")
    GOOGLE_LAYER_ARN=$(aws lambda list-layer-versions --layer-name kabukan-layer-google-fixed --region $REGION --query 'LayerVersions[0].LayerVersionArn' --output text 2>/dev/null || echo "")
    
    # Layerが存在するかチェック
    LAYERS=""
    if [[ -n "$SCRAPING_LAYER_ARN" ]] && [[ "$SCRAPING_LAYER_ARN" != "None" ]]; then
        LAYERS="$LAYERS $SCRAPING_LAYER_ARN"
        log_info "スクレイピングレイヤーを追加: $SCRAPING_LAYER_ARN"
    else
        log_warn "スクレイピングレイヤーが見つかりません"
    fi
    
    if [[ -n "$WEB_LAYER_ARN" ]] && [[ "$WEB_LAYER_ARN" != "None" ]]; then
        LAYERS="$LAYERS $WEB_LAYER_ARN"
        log_info "Webレイヤーを追加: $WEB_LAYER_ARN"
    else
        log_warn "Webレイヤーが見つかりません"
    fi
    
    if [[ -n "$GOOGLE_LAYER_ARN" ]] && [[ "$GOOGLE_LAYER_ARN" != "None" ]]; then
        LAYERS="$LAYERS $GOOGLE_LAYER_ARN"
        log_info "Googleレイヤーを追加: $GOOGLE_LAYER_ARN"
    else
        log_warn "Googleレイヤーが見つかりません"
    fi
    
    # Layerをアタッチ
    if [[ -n "$LAYERS" ]]; then
        aws lambda update-function-configuration \
            --function-name $LAMBDA_FUNCTION_NAME \
            --layers $LAYERS \
            --region $REGION > /dev/null
        log_info "✅ Layersのアタッチ完了"
    else
        log_warn "アタッチするLayerが見つかりませんでした"
    fi
}

# Slack通知Lambda関数のデプロイ
deploy_slack_lambda() {
    log_info "=== Slack通知Lambda関数 ($SLACK_LAMBDA_FUNCTION_NAME) をデプロイ中 ==="
    
    if [[ ! -f "slack_notifier_lambda.py" ]]; then
        log_warn "slack_notifier_lambda.pyが見つかりません。スキップします。"
        return
    fi
    
    # Slack用パッケージ作成
    mkdir -p temp_slack_lambda
    cp slack_notifier_lambda.py temp_slack_lambda/
    cd temp_slack_lambda
    
    # 軽量な依存関係のみインストール
    echo "requests==2.32.3" > requirements_slack.txt
    pip install -r requirements_slack.txt -t . --quiet
    
    zip -r ../slack_notifier_deploy.zip . > /dev/null
    cd ..
    rm -rf temp_slack_lambda
    
    # Slack Lambda関数の存在確認とデプロイ
    if aws lambda get-function --function-name $SLACK_LAMBDA_FUNCTION_NAME --region $REGION &>/dev/null; then
        log_info "既存のSlack Lambda関数を更新中..."
        aws lambda update-function-code \
            --function-name $SLACK_LAMBDA_FUNCTION_NAME \
            --zip-file fileb://slack_notifier_deploy.zip \
            --region $REGION > /dev/null
        log_info "✅ 既存Slack Lambda関数の更新完了"
    else
        log_info "新しいSlack Lambda関数を作成中..."
        aws lambda create-function \
            --function-name $SLACK_LAMBDA_FUNCTION_NAME \
            --runtime python3.9 \
            --role arn:aws:iam::502674413540:role/lambda-execution-role \
            --handler slack_notifier_lambda.lambda_handler \
            --zip-file fileb://slack_notifier_deploy.zip \
            --timeout 60 \
            --memory-size 128 \
            --environment Variables="{SLACK_BOT_TOKEN=$SLACK_BOT_TOKEN,SLACK_CHANNEL_ID=$SLACK_CHANNEL_ID}" \
            --region $REGION > /dev/null
        log_info "✅ 新しいSlack Lambda関数の作成完了"
    fi
    
    rm slack_notifier_deploy.zip
}

# 使用方法
echo "使用方法:"
echo "  ./deploy_lambda.sh [main|slack|all]"
echo ""

if [[ $# -eq 0 ]] || [[ "$1" == "all" ]]; then
    log_info "全てのLambda関数をデプロイします..."
    deploy_main_lambda
    attach_layers
    deploy_slack_lambda
elif [[ "$1" == "main" ]]; then
    deploy_main_lambda
    attach_layers
elif [[ "$1" == "slack" ]]; then
    deploy_slack_lambda
else
    log_error "無効なオプション: $1"
    log_info "使用可能なオプション: main, slack, all"
    exit 1
fi

# デプロイ結果の確認
log_info "=== デプロイ結果の確認 ==="
aws lambda list-functions --region $REGION --query "Functions[?contains(FunctionName, 'kabukan') || contains(FunctionName, 'slack-notifier')].{Name:FunctionName,Runtime:Runtime,LastModified:LastModified}" --output table

log_info "=== Lambda関数デプロイ完了 ==="
log_info "次のステップ:"
log_info "1. ./setup_eventbridge_daily_monthly.sh でスケジュール設定"
log_info "2. 手動テスト実行:"
log_info "   aws lambda invoke --function-name $LAMBDA_FUNCTION_NAME --payload '{\"execution_type\":\"daily\"}' response.json --region $REGION"