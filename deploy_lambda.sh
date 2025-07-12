#!/bin/bash
# Lambda用デプロイパッケージ作成スクリプト

echo "🚀 AWS Lambda用パッケージを作成中..."

# 作業ディレクトリの準備
rm -rf lambda_package
rm -f lambda_deploy.zip
mkdir lambda_package

# 依存関係のインストール
echo "📦 依存関係をインストール中..."
pip install -r requirements_lambda.txt -t lambda_package

# アプリケーションファイルをコピー
echo "📁 アプリケーションファイルをコピー中..."
cp lambda_main.py lambda_package/
cp data_fetcher.py lambda_package/
cp analyzer.py lambda_package/
cp mcp_client.py lambda_package/
cp slack_client.py lambda_package/
cp config_lambda.py lambda_package/config.py  # Lambda用のconfigを使用

# Lambda関数のエントリーポイントを設定
# lambda_main.pyをindex.pyにリネームして、ハンドラーをindex.lambda_handlerにする
mv lambda_package/lambda_main.py lambda_package/index.py

# zipファイルの作成
echo "📦 zipパッケージを作成中..."
cd lambda_package
zip -r ../lambda_deploy.zip . -x "*.pyc" "__pycache__/*"
cd ..

# パッケージサイズの確認
PACKAGE_SIZE=$(du -h lambda_deploy.zip | cut -f1)
echo "✅ Lambda用パッケージ作成完了!"
echo "📦 ファイル: lambda_deploy.zip"
echo "📏 サイズ: $PACKAGE_SIZE"

# 注意事項の表示
echo ""
echo "📋 次の手順:"
echo "1. AWSコンソールでLambda関数を作成"
echo "2. ランタイム: Python 3.9以上を選択"
echo "3. ハンドラー: index.lambda_handler に設定"
echo "4. lambda_deploy.zip をアップロード"
echo "5. 環境変数を設定:"
echo "   - GOOGLE_SHEETS_CREDENTIALS_PATH"
echo "   - SPREADSHEET_ID"
echo "   - GOOGLE_API_KEY"
echo "   - SLACK_BOT_TOKEN"
echo "   - SLACK_CHANNEL"
echo "6. EventBridgeルールを作成して定期実行を設定"
echo ""
echo "⚠️  Google認証情報は以下のいずれかの方法で設定:"
echo "   A) S3にアップロードして環境変数でS3パスを指定"
echo "   B) 環境変数GOOGLE_CREDENTIALS_JSONに直接JSON文字列を設定"
