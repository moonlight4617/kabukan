#!/bin/bash

# Lambda Layers専用デプロイスクリプト
# 現在使用中の3つのLayerを個別にデプロイ

set -e

# 設定
REGION="ap-northeast-1"

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

log_info "=== Lambda Layers デプロイ開始 ==="

# 1. スクレイピングレイヤー
deploy_scraping_layer() {
    log_info "1. スクレイピングレイヤーをデプロイ中..."
    
    if [[ ! -f "requirements_layer_scraping.txt" ]]; then
        log_error "requirements_layer_scraping.txtが見つかりません"
        return 1
    fi
    
    mkdir -p temp_layer_scraping/python
    cd temp_layer_scraping
    
    log_info "依存関係をインストール中..."
    pip install -r ../requirements_layer_scraping.txt -t python/ --quiet
    
    log_info "ZIPファイルを作成中..."
    zip -r ../lambda_layer_scraping.zip python/ > /dev/null
    
    cd ..
    rm -rf temp_layer_scraping
    
    log_info "AWS Lambda Layerを作成中..."
    SCRAPING_LAYER_ARN=$(aws lambda publish-layer-version \
        --layer-name kabukan-layer-scraping \
        --zip-file fileb://lambda_layer_scraping.zip \
        --compatible-runtimes python3.9 \
        --description "Web scraping libraries: beautifulsoup4, tqdm, frozendict" \
        --region $REGION \
        --query 'LayerVersionArn' \
        --output text)
    
    if [[ $? -eq 0 ]]; then
        log_info "✅ スクレイピングレイヤー作成完了: $SCRAPING_LAYER_ARN"
        rm lambda_layer_scraping.zip
        return 0
    else
        log_error "❌ スクレイピングレイヤー作成失敗"
        return 1
    fi
}

# 2. Web・ネットワークレイヤー
deploy_web_layer() {
    log_info "2. Web・ネットワークレイヤーをデプロイ中..."
    
    if [[ ! -f "requirements_layer_web.txt" ]]; then
        log_error "requirements_layer_web.txtが見つかりません"
        return 1
    fi
    
    mkdir -p temp_layer_web/python
    cd temp_layer_web
    
    log_info "依存関係をインストール中..."
    pip install -r ../requirements_layer_web.txt -t python/ --quiet
    
    log_info "ZIPファイルを作成中..."
    zip -r ../lambda_layer_web.zip python/ > /dev/null
    
    cd ..
    rm -rf temp_layer_web
    
    log_info "AWS Lambda Layerを作成中..."
    WEB_LAYER_ARN=$(aws lambda publish-layer-version \
        --layer-name kabukan-layer-web \
        --zip-file fileb://lambda_layer_web.zip \
        --compatible-runtimes python3.9 \
        --description "Web and network libraries: cffi, curl_cffi, websockets, peewee" \
        --region $REGION \
        --query 'LayerVersionArn' \
        --output text)
    
    if [[ $? -eq 0 ]]; then
        log_info "✅ Web・ネットワークレイヤー作成完了: $WEB_LAYER_ARN"
        rm lambda_layer_web.zip
        return 0
    else
        log_error "❌ Web・ネットワークレイヤー作成失敗"
        return 1
    fi
}

# 3. Google API・生成AIレイヤー
deploy_google_layer() {
    log_info "3. Google API・生成AIレイヤーをデプロイ中..."
    
    if [[ ! -f "requirements_layer_google.txt" ]]; then
        log_error "requirements_layer_google.txtが見つかりません"
        return 1
    fi
    
    mkdir -p temp_layer_google/python
    cd temp_layer_google
    
    log_info "依存関係をインストール中..."
    pip install -r ../requirements_layer_google.txt -t python/ --quiet
    
    log_info "ZIPファイルを作成中..."
    zip -r ../lambda_layer_google.zip python/ > /dev/null
    
    cd ..
    rm -rf temp_layer_google
    
    log_info "AWS Lambda Layerを作成中..."
    GOOGLE_LAYER_ARN=$(aws lambda publish-layer-version \
        --layer-name kabukan-layer-google-fixed \
        --zip-file fileb://lambda_layer_google.zip \
        --compatible-runtimes python3.9 \
        --description "Google APIs and AI: google-generativeai, protobuf==5.29.5, grpcio" \
        --region $REGION \
        --query 'LayerVersionArn' \
        --output text)
    
    if [[ $? -eq 0 ]]; then
        log_info "✅ Google API・生成AIレイヤー作成完了: $GOOGLE_LAYER_ARN"
        rm lambda_layer_google.zip
        return 0
    else
        log_error "❌ Google API・生成AIレイヤー作成失敗"
        return 1
    fi
}

# レイヤーデプロイの実行
echo "使用方法:"
echo "  ./deploy_layers.sh [all|scraping|web|google]"
echo ""

if [[ $# -eq 0 ]] || [[ "$1" == "all" ]]; then
    log_info "全てのレイヤーをデプロイします..."
    deploy_scraping_layer
    deploy_web_layer
    deploy_google_layer
elif [[ "$1" == "scraping" ]]; then
    deploy_scraping_layer
elif [[ "$1" == "web" ]]; then
    deploy_web_layer
elif [[ "$1" == "google" ]]; then
    deploy_google_layer
else
    log_error "無効なオプション: $1"
    log_info "使用可能なオプション: all, scraping, web, google"
    exit 1
fi

# 結果の確認
log_info "=== デプロイ済みLayerの確認 ==="
aws lambda list-layers --region $REGION --query "Layers[?contains(LayerName, 'kabukan')].{Name:LayerName,LatestVersion:LatestMatchingVersion.Version,Description:LatestMatchingVersion.Description}" --output table

log_info "=== Layer デプロイ完了 ==="
log_info "次のステップ:"
log_info "1. ./deploy_lambda.sh でLambda関数をデプロイ"
log_info "2. ./setup_eventbridge_daily_monthly.sh でスケジュール設定"