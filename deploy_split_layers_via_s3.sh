#!/bin/bash

# 分割Lambda Layers S3経由デプロイスクリプト
echo "🚀 分割Lambda LayersをS3経由でデプロイします..."

# 設定値（適宜変更してください）
S3_BUCKET="your-lambda-deployment-bucket"  # S3バケット名を指定
FUNCTION_NAME="investment-advice-system"
LAYER1_NAME="investment-advice-layer-data"
LAYER2_NAME="investment-advice-layer-google"
REGION="ap-northeast-1"  # 東京リージョン

echo "📋 設定確認:"
echo "  S3バケット: $S3_BUCKET"
echo "  Lambda関数名: $FUNCTION_NAME"
echo "  Layer 1名: $LAYER1_NAME (データ処理系)"
echo "  Layer 2名: $LAYER2_NAME (Google API系)"
echo "  リージョン: $REGION"
echo ""

# 必要ファイルの存在確認
echo "📁 ファイル存在確認..."
for file in lambda_layer1_data.zip lambda_layer2_google.zip lambda_deploy_light.zip; do
    if [ ! -f "$file" ]; then
        echo "❌ 必要ファイルが見つかりません: $file"
        echo "   まず create_split_layers.sh を実行してください"
        exit 1
    fi
done
echo "✅ 必要ファイル確認完了"

# 1. Layer 1をS3にアップロード
echo "📦 Step 1: Layer 1 (データ処理系) をS3にアップロード中..."
aws s3 cp lambda_layer1_data.zip s3://$S3_BUCKET/lambda_layer1_data.zip
if [ $? -eq 0 ]; then
    echo "✅ Layer 1 S3アップロード完了"
else
    echo "❌ Layer 1 S3アップロード失敗"
    exit 1
fi

# 2. Layer 2をS3にアップロード
echo "📦 Step 2: Layer 2 (Google API系) をS3にアップロード中..."
aws s3 cp lambda_layer2_google.zip s3://$S3_BUCKET/lambda_layer2_google.zip
if [ $? -eq 0 ]; then
    echo "✅ Layer 2 S3アップロード完了"
else
    echo "❌ Layer 2 S3アップロード失敗"
    exit 1
fi

# 3. Lambda本体をS3にアップロード
echo "📦 Step 3: Lambda本体をS3にアップロード中..."
aws s3 cp lambda_deploy_light.zip s3://$S3_BUCKET/lambda_deploy_light.zip
if [ $? -eq 0 ]; then
    echo "✅ Lambda本体 S3アップロード完了"
else
    echo "❌ Lambda本体 S3アップロード失敗"
    exit 1
fi

# 4. Layer 1作成
echo "🔧 Step 4: Layer 1 (データ処理系) 作成中..."
LAYER1_VERSION_ARN=$(aws lambda publish-layer-version \
    --layer-name $LAYER1_NAME \
    --content S3Bucket=$S3_BUCKET,S3Key=lambda_layer1_data.zip \
    --compatible-runtimes python3.9 python3.10 python3.11 \
    --description "Investment advice system - Data processing libraries (pandas, numpy, yfinance)" \
    --region $REGION \
    --query 'LayerVersionArn' \
    --output text)

if [ $? -eq 0 ]; then
    echo "✅ Layer 1作成完了: $LAYER1_VERSION_ARN"
else
    echo "❌ Layer 1作成失敗"
    exit 1
fi

# 5. Layer 2作成
echo "🔧 Step 5: Layer 2 (Google API系) 作成中..."
LAYER2_VERSION_ARN=$(aws lambda publish-layer-version \
    --layer-name $LAYER2_NAME \
    --content S3Bucket=$S3_BUCKET,S3Key=lambda_layer2_google.zip \
    --compatible-runtimes python3.9 python3.10 python3.11 \
    --description "Investment advice system - Google API libraries (google-generativeai, protobuf)" \
    --region $REGION \
    --query 'LayerVersionArn' \
    --output text)

if [ $? -eq 0 ]; then
    echo "✅ Layer 2作成完了: $LAYER2_VERSION_ARN"
else
    echo "❌ Layer 2作成失敗"
    exit 1
fi

# 6. Lambda関数作成
echo "🔧 Step 6: Lambda関数作成中..."
aws lambda create-function \
    --function-name $FUNCTION_NAME \
    --runtime python3.9 \
    --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/lambda-execution-role \
    --handler index.lambda_handler \
    --code S3Bucket=$S3_BUCKET,S3Key=lambda_deploy_light.zip \
    --timeout 300 \
    --memory-size 512 \
    --region $REGION \
    --description "Investment advice system with Slack integration"

if [ $? -eq 0 ]; then
    echo "✅ Lambda関数作成完了"
else
    echo "⚠️  Lambda関数が既に存在する可能性があります。更新を試行..."
    
    # 関数が既に存在する場合は更新
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --s3-bucket $S3_BUCKET \
        --s3-key lambda_deploy_light.zip \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        echo "✅ Lambda関数コード更新完了"
    else
        echo "❌ Lambda関数作成/更新失敗"
        exit 1
    fi
fi

# 7. 両方のLayerをLambda関数に適用
echo "🔗 Step 7: 両方のLayerをLambda関数に適用中..."
aws lambda update-function-configuration \
    --function-name $FUNCTION_NAME \
    --layers $LAYER1_VERSION_ARN $LAYER2_VERSION_ARN \
    --region $REGION

if [ $? -eq 0 ]; then
    echo "✅ 両Layer適用完了"
else
    echo "❌ Layer適用失敗"
    exit 1
fi

# 8. 環境変数設定（例）
echo "🔧 Step 8: 環境変数設定中..."
aws lambda update-function-configuration \
    --function-name $FUNCTION_NAME \
    --environment Variables='{
        "GOOGLE_SHEETS_CREDENTIALS_PATH":"s3://your-config-bucket/google-credentials.json",
        "SPREADSHEET_ID":"your_spreadsheet_id",
        "GOOGLE_API_KEY":"your_google_api_key",
        "SLACK_BOT_TOKEN":"your_slack_bot_token",
        "SLACK_CHANNEL":"#investment-advice"
    }' \
    --region $REGION

if [ $? -eq 0 ]; then
    echo "✅ 環境変数設定完了"
else
    echo "⚠️  環境変数設定をスキップ（手動で設定してください）"
fi

echo ""
echo "🎉 分割Lambda Layers デプロイ完了！"
echo ""
echo "📊 適用されたLayers:"
echo "  1. $LAYER1_NAME: データ処理系ライブラリ"
echo "  2. $LAYER2_NAME: Google API系ライブラリ"
echo ""
echo "📋 次の手順:"
echo "1. AWSコンソールで環境変数を確認・更新"
echo "2. IAM ロールの権限確認"
echo "3. EventBridge（CloudWatch Events）で定期実行設定"
echo "4. テスト実行で動作確認"
echo ""
echo "🔧 EventBridge設定例:"
echo "  - ルール名: investment-advice-daily"
echo "  - スケジュール: cron(0 21 * * ? *)  # 毎日21:00 UTC（日本時間6:00）"
echo "  - ターゲット: Lambda関数 $FUNCTION_NAME"
