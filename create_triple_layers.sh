#!/bin/bash

# 3分割Lambda Layers作成スクリプト
echo "🚀 3分割Lambda Layersを作成中..."

# 既存のパッケージとディレクトリをクリーンアップ
echo "🧹 既存ファイルをクリーンアップ中..."
rm -rf lambda_layer1a_pandas lambda_layer1b_web lambda_layer2_google
rm -f lambda_layer1a_pandas.zip lambda_layer1b_web.zip lambda_layer2_google.zip

# Layer 1A: 基本データ処理（pandas, numpy）
echo "📦 Layer 1A (pandas/numpy) を作成中..."
mkdir -p lambda_layer1a_pandas/python
pip install -r requirements_layer1a_pandas.txt -t lambda_layer1a_pandas/python --upgrade --no-cache-dir

if [ $? -eq 0 ]; then
    echo "✅ Layer 1A 依存関係インストール完了"
else
    echo "❌ Layer 1A 依存関係インストール失敗"
    exit 1
fi

# Layer 1A をzipに圧縮（最大圧縮）
echo "📦 Layer 1A zip作成中..."
cd lambda_layer1a_pandas
zip -r9 ../lambda_layer1a_pandas.zip python/
cd ..

if [ $? -eq 0 ]; then
    LAYER1A_SIZE=$(ls -lh lambda_layer1a_pandas.zip | awk '{print $5}')
    echo "✅ Layer 1A 作成完了: $LAYER1A_SIZE"
else
    echo "❌ Layer 1A zip作成失敗"
    exit 1
fi

# Layer 1B: Web・ファイナンス系ライブラリ
echo "📦 Layer 1B (Web/Finance) を作成中..."
mkdir -p lambda_layer1b_web/python
pip install -r requirements_layer1b_web.txt -t lambda_layer1b_web/python --upgrade --no-cache-dir

if [ $? -eq 0 ]; then
    echo "✅ Layer 1B 依存関係インストール完了"
else
    echo "❌ Layer 1B 依存関係インストール失敗"
    exit 1
fi

# Layer 1B をzipに圧縮（最大圧縮）
echo "📦 Layer 1B zip作成中..."
cd lambda_layer1b_web
zip -r9 ../lambda_layer1b_web.zip python/
cd ..

if [ $? -eq 0 ]; then
    LAYER1B_SIZE=$(ls -lh lambda_layer1b_web.zip | awk '{print $5}')
    echo "✅ Layer 1B 作成完了: $LAYER1B_SIZE"
else
    echo "❌ Layer 1B zip作成失敗"
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
MAX_BYTES=$((50 * 1024 * 1024))  # 50MB

for file in lambda_layer1a_pandas.zip lambda_layer1b_web.zip lambda_layer2_google.zip; do
    if [ -f "$file" ]; then
        FILE_BYTES=$(stat -c%s "$file")
        FILE_MB=$(awk "BEGIN {printf \"%.1f\", $FILE_BYTES/1024/1024}")
        if [ $FILE_BYTES -le $MAX_BYTES ]; then
            echo "✅ $file: 制限内 (${FILE_MB}MB / 50MB)"
        else
            echo "❌ $file: 制限超過 (${FILE_MB}MB / 50MB)"
        fi
    fi
done

echo ""
echo "🎉 3分割Lambda Layers作成完了！"
echo ""
echo "📋 構成:"
echo "  Layer 1A: pandas, numpy (基本データ処理)"
echo "  Layer 1B: yfinance, websockets, curl_cffi (Web/Finance)"  
echo "  Layer 2:  google-generativeai, protobuf (Google API)"
echo ""
echo "📋 次の手順:"
echo "1. deploy_triple_layers_via_s3.sh でS3経由デプロイ"
echo "2. または AWSコンソールで3つのLayerを手動アップロード"
echo "3. Lambda関数に3つのLayerを適用"
