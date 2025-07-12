#!/bin/bash
"""
ngrok起動スクリプト
Slack Bot開発環境用
"""

echo "🌐 ngrokを起動してSlack Botサーバーを公開します..."
echo "ポート5000をHTTPS経由で公開します"
echo ""
echo "📋 手順:"
echo "1. ngrokが起動したらHTTPS URLをコピー"
echo "2. Slack App管理画面 → Event Subscriptions → Request URL に設定"
echo "3. URL: https://xxxxxx.ngrok.io/slack/events"
echo ""
echo "🚀 ngrok起動中..."

ngrok http 5000
