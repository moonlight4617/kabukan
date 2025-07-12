#!/bin/bash
# Lambda本体用デプロイパッケージ作成スクリプト（Layer使用版）

echo "🚀 AWS Lambda本体用パッケージを作成中（Layer使用版）..."

# 作業ディレクトリの準備
rm -rf lambda_package_light
rm -f lambda_deploy_light.zip
mkdir lambda_package_light

# 軽量な依存関係のインストール
echo "📦 軽量な依存関係をインストール中..."
pip install -r requirements_lambda_light.txt -t lambda_package_light

# アプリケーションファイルをコピー
echo "📁 アプリケーションファイルをコピー中..."
cp lambda_main.py lambda_package_light/
cp data_fetcher.py lambda_package_light/
cp analyzer.py lambda_package_light/
cp mcp_client.py lambda_package_light/
cp slack_client.py lambda_package_light/
cp config_lambda.py lambda_package_light/config.py

# Lambda関数のエントリーポイントを設定
mv lambda_package_light/lambda_main.py lambda_package_light/index.py

# zipファイルの作成
echo "📦 zipパッケージを作成中..."
cd lambda_package_light
zip -r ../lambda_deploy_light.zip . -x "*.pyc" "*/__pycache__/*"
cd ..

# パッケージサイズの確認
PACKAGE_SIZE=$(du -h lambda_deploy_light.zip | cut -f1)
echo "✅ Lambda本体用パッケージ作成完了!"
echo "📦 ファイル: lambda_deploy_light.zip"
echo "📏 サイズ: $PACKAGE_SIZE"

echo ""
echo "📋 次の手順:"
echo "1. 事前にLambda Layerを作成済みであることを確認"
echo "2. AWSコンソールでLambda関数を作成"
echo "3. ランタイム: Python 3.9以上を選択"
echo "4. ハンドラー: index.lambda_handler に設定"
echo "5. lambda_deploy_light.zip をアップロード"
echo "6. ⚠️  重要: Lambda関数の「レイヤー」タブで作成済みLayerを追加"
echo "7. 環境変数を設定:"
echo "   - GOOGLE_SHEETS_CREDENTIALS_PATH"
echo "   - SPREADSHEET_ID"
echo "   - GOOGLE_API_KEY"
echo "   - SLACK_BOT_TOKEN"
echo "   - SLACK_CHANNEL"
echo "8. EventBridgeルールを作成して定期実行を設定"
echo ""
echo "⚠️  Google認証情報は以下のいずれかの方法で設定:"
echo "   A) S3にアップロードして環境変数でS3パスを指定"
echo "   B) 環境変数GOOGLE_CREDENTIALS_JSONに直接JSON文字列を設定"
