#!/bin/bash
# 5分割Lambda Layers作成スクリプト

echo "🚀 5分割Lambda Layersを作成中..."

# 既存ファイルをクリーンアップ
echo "🧹 既存ファイルをクリーンアップ中..."
rm -rf layer_*

# Layer 1A: pandas/numpy (基本データ処理)
echo "📦 Layer 1A (pandas/numpy) を作成中..."
mkdir -p layer_1a/python
cd layer_1a
pip install -r ../requirements_layer1a_pandas.txt -t python/
if [ $? -eq 0 ]; then
    echo "✅ Layer 1A 依存関係インストール完了"
    echo "📦 Layer 1A zip作成中..."
    zip -r9 ../lambda_layer1a_pandas.zip python/
    cd ..
    echo "✅ Layer 1A 作成完了: $(du -h lambda_layer1a_pandas.zip | cut -f1)"
else
    echo "❌ Layer 1A インストールエラー"
    exit 1
fi

# Layer 1B1: yfinance (重いファイナンスライブラリ)
echo "📦 Layer 1B1 (yfinance) を作成中..."
mkdir -p layer_1b1/python
cd layer_1b1
pip install -r ../requirements_layer1b1_yfinance.txt -t python/
if [ $? -eq 0 ]; then
    echo "✅ Layer 1B1 依存関係インストール完了"
    echo "📦 Layer 1B1 zip作成中..."
    zip -r9 ../lambda_layer1b1_yfinance.zip python/
    cd ..
    echo "✅ Layer 1B1 作成完了: $(du -h lambda_layer1b1_yfinance.zip | cut -f1)"
else
    echo "❌ Layer 1B1 インストールエラー"
    exit 1
fi

# Layer 1B2: スクレイピング系 (beautifulsoup4, tqdm, frozendict)
echo "📦 Layer 1B2 (scraping) を作成中..."
mkdir -p layer_1b2/python
cd layer_1b2
pip install -r ../requirements_layer1b2_scraping.txt -t python/
if [ $? -eq 0 ]; then
    echo "✅ Layer 1B2 依存関係インストール完了"
    echo "📦 Layer 1B2 zip作成中..."
    zip -r9 ../lambda_layer1b2_scraping.zip python/
    cd ..
    echo "✅ Layer 1B2 作成完了: $(du -h lambda_layer1b2_scraping.zip | cut -f1)"
else
    echo "❌ Layer 1B2 インストールエラー"
    exit 1
fi

# Layer 1C: Web/Network (軽量なライブラリ)
echo "📦 Layer 1C (web/network) を作成中..."
mkdir -p layer_1c/python
cd layer_1c
pip install -r ../requirements_layer1c_web.txt -t python/
if [ $? -eq 0 ]; then
    echo "✅ Layer 1C 依存関係インストール完了"
    echo "📦 Layer 1C zip作成中..."
    zip -r9 ../lambda_layer1c_web.zip python/
    cd ..
    echo "✅ Layer 1C 作成完了: $(du -h lambda_layer1c_web.zip | cut -f1)"
else
    echo "❌ Layer 1C インストールエラー"
    exit 1
fi

# Layer 2: Google API (変更なし)
echo "📦 Layer 2 (Google API) を作成中..."
mkdir -p layer_2/python
cd layer_2
pip install -r ../requirements_layer2_google.txt -t python/
if [ $? -eq 0 ]; then
    echo "✅ Layer 2 依存関係インストール完了"
    echo "📦 Layer 2 zip作成中..."
    zip -r9 ../lambda_layer2_google.zip python/
    cd ..
    echo "✅ Layer 2 作成完了: $(du -h lambda_layer2_google.zip | cut -f1)"
else
    echo "❌ Layer 2 インストールエラー"
    exit 1
fi

# クリーンアップ
echo "🧹 一時ディレクトリをクリーンアップ中..."
rm -rf layer_*

# サイズ確認
echo ""
echo "📊 作成されたLayerのサイズ確認:"
ls -lh lambda_layer*.zip

# 50MB制限チェック
echo ""
echo "🎯 50MB制限チェック:"
for file in lambda_layer*.zip; do
    size=$(du -m "$file" | cut -f1)
    if [ $size -lt 50 ]; then
        echo "✅ $file: 制限内 (${size}.0MB / 50MB)"
    else
        echo "❌ $file: 制限超過 (${size}.0MB / 50MB)"
    fi
done

echo ""
echo "🎉 5分割Lambda Layers作成完了！"
echo ""
echo "📋 構成:"
echo "  Layer 1A: pandas, numpy (基本データ処理)"
echo "  Layer 1B1: yfinance (金融データ)"
echo "  Layer 1B2: beautifulsoup4, tqdm (スクレイピング)"
echo "  Layer 1C: websockets, curl_cffi, protobuf (Web/Network)"
echo "  Layer 2:  google-generativeai, grpcio (Google API)"
echo ""
echo "📋 次の手順:"
echo "1. deploy_penta_layers_via_s3.sh でS3経由デプロイ"
echo "2. または AWSコンソールで5つのLayerを手動アップロード"
echo "3. Lambda関数に5つのLayerを適用（最大5層まで可能）"
