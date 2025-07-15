#!/bin/bash
# Lambda関数設定スクリプト

FUNCTION_NAME="kabukan"
AWS_REGION="ap-northeast-1"

echo "🔧 Lambda関数の設定を開始..."

# 最新のレイヤーバージョンを取得する関数
get_latest_layer_version() {
    local layer_name=$1
    aws lambda list-layer-versions \
        --layer-name "$layer_name" \
        --region "$AWS_REGION" \
        --query 'LayerVersions[0].Version' \
        --output text 2>/dev/null
}

# 1. レイヤーのバージョンを取得
echo "📦 レイヤーバージョンを取得中..."
PANDAS_VERSION=$(get_latest_layer_version "kabukan-layer-pandas")
SCRAPING_VERSION=$(get_latest_layer_version "kabukan-layer-scraping")
WEB_VERSION=$(get_latest_layer_version "kabukan-layer-web")
GOOGLE_VERSION=$(get_latest_layer_version "kabukan-layer-google")

echo "取得したバージョン:"
echo "  - pandas: $PANDAS_VERSION"
echo "  - scraping: $SCRAPING_VERSION"
echo "  - web: $WEB_VERSION"
echo "  - google: $GOOGLE_VERSION"

# バージョンが取得できない場合はエラー
if [[ "$PANDAS_VERSION" == "None" || "$SCRAPING_VERSION" == "None" || "$WEB_VERSION" == "None" || "$GOOGLE_VERSION" == "None" ]]; then
    echo "❌ レイヤーバージョンの取得に失敗しました"
    echo "先にdeploy_quad_layers_via_s3.shを実行してください"
    exit 1
fi

# 2. 既存のレイヤーをクリアしてから新しいレイヤーを追加
echo "🧹 既存のレイヤーをクリア中..."
if aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --layers \
    --region "$AWS_REGION" > /dev/null; then
    echo "✅ 既存レイヤーのクリア完了"
else
    echo "❌ 既存レイヤーのクリアエラー"
fi

# 少し待ってから新しいレイヤーを追加
echo "⏳ 設定反映のため5秒待機中..."
sleep 5

echo "🔗 新しいレイヤーを追加中（サイズ制限により軽量版のみ）..."
echo "⚠️  pandasレイヤー(42MB)は大きすぎるため除外します"
LAYER_ARNS=(
    "arn:aws:lambda:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):layer:kabukan-layer-scraping:$SCRAPING_VERSION"
    "arn:aws:lambda:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):layer:kabukan-layer-web:$WEB_VERSION"
    "arn:aws:lambda:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):layer:kabukan-layer-google:$GOOGLE_VERSION"
)

# 新しいレイヤーを追加
if aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --layers "${LAYER_ARNS[@]}" \
    --region "$AWS_REGION" > /dev/null; then
    echo "✅ 新しいレイヤーの追加完了"
else
    echo "❌ 新しいレイヤーの追加エラー"
fi

# 3. .envファイルから環境変数を読み込み
echo "⏳ 設定反映のため5秒待機中..."
sleep 5

echo "🌍 .envファイルから環境変数を読み込み中..."

# .envファイルが存在するかチェック
if [ ! -f ".env" ]; then
    echo "❌ .envファイルが見つかりません"
    exit 1
fi

# .envファイルから環境変数を読み込み
source .env

# 環境変数の設定
ENVIRONMENT_VARS=$(cat <<EOF
{
    "Variables": {
        "GOOGLE_API_KEY": "${GOOGLE_API_KEY:-}",
        "ALPHA_VANTAGE_API_KEY": "${ALPHA_VANTAGE_API_KEY:-}",
        "GOOGLE_SHEETS_CREDENTIALS_PATH": "${GOOGLE_SHEETS_CREDENTIALS_PATH:-}",
        "SPREADSHEET_ID": "${SPREADSHEET_ID:-}",
        "SLACK_BOT_TOKEN": "${SLACK_BOT_TOKEN:-}",
        "SLACK_SIGNING_SECRET": "${SLACK_SIGNING_SECRET:-}",
        "SLACK_CHANNEL": "${SLACK_CHANNEL:-}"
    }
}
EOF
)

if aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --environment "$ENVIRONMENT_VARS" \
    --region "$AWS_REGION" > /dev/null; then
    echo "✅ 環境変数の設定完了"
else
    echo "❌ 環境変数の設定エラー"
fi

# 4. タイムアウトとメモリの設定
echo "⏳ 設定反映のため5秒待機中..."
sleep 5

echo "⚙️  実行時設定を最適化中..."
if aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --timeout 300 \
    --memory-size 512 \
    --region "$AWS_REGION" > /dev/null; then
    echo "✅ 実行時設定の最適化完了"
else
    echo "❌ 実行時設定エラー"
fi

echo ""
echo "🎉 Lambda関数の設定完了！"
echo ""
echo "📋 設定内容:"
echo "1. ✅ 3つのレイヤーを追加（pandas除く）"
echo "2. ✅ 環境変数を.envから自動設定"
echo "3. ✅ タイムアウト: 5分"
echo "4. ✅ メモリ: 512MB"
echo ""
echo "💡 次の手順:"
echo "1. ✅ 環境変数は.envファイルから自動設定済み"
echo "2. IAMロールに必要な権限を追加"
echo "3. テスト実行で動作確認"
echo ""
echo "🔧 設定された環境変数:"
echo "  - GOOGLE_API_KEY: ${GOOGLE_API_KEY:0:10}..."
echo "  - SPREADSHEET_ID: ${SPREADSHEET_ID}"
echo "  - SLACK_CHANNEL: ${SLACK_CHANNEL}"