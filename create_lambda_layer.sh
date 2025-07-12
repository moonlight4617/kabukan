#!/bin/bash
# AWS Lambda Layer作成スクリプト

echo "📦 AWS Lambda Layer用パッケージを作成中..."

# 作業ディレクトリの準備
rm -rf layer_package
rm -f lambda_layer.zip
mkdir layer_package

# Layerの構造を作成（pythonディレクトリ必須）
mkdir layer_package/python

# Layer用依存関係のインストール
echo "📦 Layer用依存関係をインストール中..."
pip install -r requirements_layer.txt -t layer_package/python

# zipファイルの作成
echo "📦 Layer用zipパッケージを作成中..."
cd layer_package
zip -r ../lambda_layer.zip python -x "*.pyc" "*/__pycache__/*"
cd ..

# パッケージサイズの確認
LAYER_SIZE=$(du -h lambda_layer.zip | cut -f1)
echo "✅ Lambda Layer用パッケージ作成完了!"
echo "📦 ファイル: lambda_layer.zip"
echo "📏 サイズ: $LAYER_SIZE"

echo ""
echo "📋 次の手順:"
echo "1. AWSコンソールでLambda Layerを作成"
echo "2. lambda_layer.zip をアップロード"
echo "3. 互換ランタイム: Python 3.9, Python 3.10, Python 3.11を選択"
echo "4. Layer ARNをメモする"
echo "5. Lambda関数作成時にこのLayerを追加"
echo ""
echo "💡 Layer作成後:"
echo "   - ./deploy_lambda_with_layer.sh でLambda本体を作成"
echo "   - Lambda関数の設定でLayerを追加"
