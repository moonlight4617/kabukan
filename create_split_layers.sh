#!/bin/bash

# 分割されたLambda Layers作成スクリプト
echo "🚀 分割Lambda Layersを作成中..."

# 既存のパッケージとディレクトリをクリーンアップ
echo "🧹 既存ファイルをクリーンアップ中..."
rm -rf lambda_layer1_data lambda_layer2_google
rm -f lambda_layer1_data.zip lambda_layer2_google.zip

# Layer 1: データ処理系ライブラリ
echo "📦 Layer 1 (データ処理系) を作成中..."
mkdir -p lambda_layer1_data/python
pip install -r requirements_layer1_data.txt -t lambda_layer1_data/python --upgrade --no-cache-dir

if [ $? -eq 0 ]; then
    echo "✅ Layer 1 依存関係インストール完了"
else
    echo "❌ Layer 1 依存関係インストール失敗"
    exit 1
fi

# Layer 1 をzipに圧縮（最大圧縮）
echo "📦 Layer 1 zip作成中..."
cd lambda_layer1_data
zip -r9 ../lambda_layer1_data.zip python/
cd ..

if [ $? -eq 0 ]; then
    LAYER1_SIZE=$(ls -lh lambda_layer1_data.zip | awk '{print $5}')
    echo "✅ Layer 1 作成完了: $LAYER1_SIZE"
else
    echo "❌ Layer 1 zip作成失敗"
    exit 1
fi

# Layer 2: Google API・生成AI系ライブラリ
echo "📦 Layer 2 (Google API系) を作成中..."
mkdir -p lambda_layer2_google/python
pip install -r requirements_layer2_google.txt -t lambda_layer2_google/python --upgrade --no-cache-dir

if [ $? -eq 0 ]; then
    echo "✅ Layer 2 依存関係インストール完了"
else
    echo "❌ Layer 2 依存関係インストール失敗"
    exit 1
fi

# Layer 2 をzipに圧縮（最大圧縮）
echo "📦 Layer 2 zip作成中..."
cd lambda_layer2_google
zip -r9 ../lambda_layer2_google.zip python/
cd ..

if [ $? -eq 0 ]; then
    LAYER2_SIZE=$(ls -lh lambda_layer2_google.zip | awk '{print $5}')
    echo "✅ Layer 2 作成完了: $LAYER2_SIZE"
else
    echo "❌ Layer 2 zip作成失敗"
    exit 1
fi

# サイズ確認
echo ""
echo "📊 作成されたLayerのサイズ確認:"
ls -lh lambda_layer*.zip

echo ""
echo "🎯 50MB制限チェック:"
LAYER1_BYTES=$(stat -c%s lambda_layer1_data.zip)
LAYER2_BYTES=$(stat -c%s lambda_layer2_google.zip)
MAX_BYTES=$((50 * 1024 * 1024))  # 50MB

if [ $LAYER1_BYTES -le $MAX_BYTES ]; then
    echo "✅ Layer 1: 制限内 ($(echo "scale=1; $LAYER1_BYTES/1024/1024" | bc)MB / 50MB)"
else
    echo "❌ Layer 1: 制限超過 ($(echo "scale=1; $LAYER1_BYTES/1024/1024" | bc)MB / 50MB)"
fi

if [ $LAYER2_BYTES -le $MAX_BYTES ]; then
    echo "✅ Layer 2: 制限内 ($(echo "scale=1; $LAYER2_BYTES/1024/1024" | bc)MB / 50MB)"
else
    echo "❌ Layer 2: 制限超過 ($(echo "scale=1; $LAYER2_BYTES/1024/1024" | bc)MB / 50MB)"
fi

echo ""
echo "🎉 分割Lambda Layers作成完了！"
echo ""
echo "📋 次の手順:"
echo "1. deploy_split_layers_via_s3.sh でS3経由デプロイ"
echo "2. または AWSコンソールで両方のLayerを手動アップロード"
echo "3. Lambda関数に両方のLayerを適用"
