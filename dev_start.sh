#!/bin/bash
"""
開発環境統合起動スクリプト
Slack Bot開発を簡単に開始
"""

echo "🚀 投資アドバイス Slack Bot - 開発環境起動"
echo "=" * 50

# 環境変数チェック
if [ ! -f ".env" ]; then
    echo "❌ .envファイルが見つかりません"
    echo "💡 .envファイルを作成して必要な環境変数を設定してください"
    exit 1
fi

# 依存関係チェック
echo "📦 依存関係をチェック中..."
python -c "import slack_sdk, flask, google.generativeai" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "❌ 必要なライブラリが不足しています"
    echo "💡 pip install -r requirements.txt を実行してください"
    exit 1
fi

# メニュー表示
echo ""
echo "📋 何を実行しますか？"
echo "1) ポートフォリオ分析のみ実行"
echo "2) Slack Botサーバー起動"
echo "3) ngrok起動（別ターミナル推奨）"
echo "4) 統合テスト（分析→Slack通知）"
echo ""
read -p "選択してください (1-4): " choice

case $choice in
    1)
        echo "📊 ポートフォリオ分析を実行..."
        python main_dev.py
        ;;
    2)
        echo "🤖 Slack Botサーバーを起動..."
        echo "💡 別ターミナルでngrokも起動してください: ./start_ngrok.sh"
        python slack_bot_dev.py
        ;;
    3)
        echo "🌐 ngrokを起動..."
        echo "💡 Slack AppのWebhook URLにngrokのHTTPS URLを設定してください"
        ./start_ngrok.sh
        ;;
    4)
        echo "🧪 統合テストを実行..."
        echo "1. ポートフォリオ分析実行..."
        python main_dev.py
        echo ""
        echo "2. Slack Botサーバー起動準備..."
        echo "💡 次に別ターミナルで以下を実行してください:"
        echo "   ./start_ngrok.sh"
        echo "   python slack_bot_dev.py"
        ;;
    *)
        echo "❌ 無効な選択です"
        exit 1
        ;;
esac
