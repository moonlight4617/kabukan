#!/bin/bash
# S3経由での4つのLambda Layers一括デプロイスクリプト

S3_BUCKET="kabukan-bucket"  # 事前にS3バケットを作成してください
AWS_REGION="ap-northeast-1"  # お使いのリージョンに変更してください

echo "🚀 4つのLambda LayersをS3経由でデプロイ中..."

# S3バケット存在確認
if ! aws s3 ls "s3://$S3_BUCKET" &> /dev/null; then
    echo "❌ S3バケット s3://$S3_BUCKET が見つかりません"
    echo "💡 バケットを作成するか、スクリプト内のS3_BUCKETを変更してください"
    exit 1
fi

# Layer 1: pandas/numpy (基本データ処理)
echo "📦 Layer 1: pandas/numpy をデプロイ中..."
aws s3 cp lambda_layer1a_pandas.zip s3://$S3_BUCKET/layers/
if aws lambda publish-layer-version \
    --layer-name "kabukan-layer-pandas" \
    --description "Pandas and NumPy for data processing" \
    --content S3Bucket=$S3_BUCKET,S3Key=layers/lambda_layer1a_pandas.zip \
    --compatible-runtimes python3.9 python3.10 python3.11 \
    --region $AWS_REGION > /dev/null; then
    echo "✅ Layer 1 (pandas/numpy) デプロイ完了"
else
    echo "❌ Layer 1 デプロイエラー"
fi

# Layer 2: スクレイピング (軽量)
echo "📦 Layer 2: scraping をデプロイ中..."
aws s3 cp lambda_layer1b2_scraping.zip s3://$S3_BUCKET/layers/
if aws lambda publish-layer-version \
    --layer-name "kabukan-layer-scraping" \
    --description "BeautifulSoup4, tqdm, frozendict for web scraping" \
    --content S3Bucket=$S3_BUCKET,S3Key=layers/lambda_layer1b2_scraping.zip \
    --compatible-runtimes python3.9 python3.10 python3.11 \
    --region $AWS_REGION > /dev/null; then
    echo "✅ Layer 2 (scraping) デプロイ完了"
else
    echo "❌ Layer 2 デプロイエラー"
fi

# Layer 3: Web/Network
echo "📦 Layer 3: web/network をデプロイ中..."
aws s3 cp lambda_layer1c_web.zip s3://$S3_BUCKET/layers/
if aws lambda publish-layer-version \
    --layer-name "kabukan-layer-web" \
    --description "Websockets, curl_cffi, protobuf for network communication" \
    --content S3Bucket=$S3_BUCKET,S3Key=layers/lambda_layer1c_web.zip \
    --compatible-runtimes python3.9 python3.10 python3.11 \
    --region $AWS_REGION > /dev/null; then
    echo "✅ Layer 3 (web/network) デプロイ完了"
else
    echo "❌ Layer 3 デプロイエラー"
fi

# Layer 4: Google API
echo "📦 Layer 4: Google API をデプロイ中..."
aws s3 cp lambda_layer2_google.zip s3://$S3_BUCKET/layers/
if aws lambda publish-layer-version \
    --layer-name "kabukan-layer-google" \
    --description "Google Generative AI and related libraries" \
    --content S3Bucket=$S3_BUCKET,S3Key=layers/lambda_layer2_google.zip \
    --compatible-runtimes python3.9 python3.10 python3.11 \
    --region $AWS_REGION > /dev/null; then
    echo "✅ Layer 4 (Google API) デプロイ完了"
else
    echo "❌ Layer 4 デプロイエラー"
fi

# Lambda関数本体のデプロイ
echo "📦 Lambda関数本体をデプロイ中..."
aws s3 cp lambda_deploy_light.zip s3://$S3_BUCKET/functions/
if aws lambda update-function-code \
    --function-name "kabukan" \
    --s3-bucket $S3_BUCKET \
    --s3-key functions/lambda_deploy_light.zip \
    --region $AWS_REGION > /dev/null; then
    echo "✅ Lambda関数本体デプロイ完了"
else
    echo "❌ Lambda関数本体デプロイエラー"
fi

echo ""
echo "🎉 デプロイ完了！"
echo ""
echo "📋 次の手順:"
echo "1. AWSコンソールでLambda関数にアクセス"
echo "2. 設定 > Layer で以下を追加:"
echo "   - kabukan-layer-pandas"
echo "   - kabukan-layer-scraping"  
echo "   - kabukan-layer-web"
echo "   - kabukan-layer-google"
echo "3. yfinanceは実行時にインポートエラーになる可能性があります"
echo "   その場合は代替のファイナンスAPIを検討してください"
echo ""
echo "⚠️  注意: yfinanceライブラリは依存関係が複雑で50MB制限を超過しました"
echo "   投資データ取得には別のAPIやライブラリの使用を推奨します"
