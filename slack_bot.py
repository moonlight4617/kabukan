#!/usr/bin/env python3
"""
Slack Bot サーバー
SlackからのイベントやメッセージをWebhookで受信し、
Gemini APIを使用して投資関連の質問に回答する
"""

import os
import json
import hashlib
import hmac
import time
from flask import Flask, request, jsonify
from slack_client import SlackClient
import config

app = Flask(__name__)

# Slack クライアントの初期化
slack_client = SlackClient()

def verify_slack_signature(request_body, timestamp, signature):
    """
    Slackからのリクエストの署名を検証
    Args:
        request_body: リクエストボディ
        timestamp: タイムスタンプ
        signature: 署名
    Returns:
        bool: 署名が正しいかどうか
    """
    if not config.SLACK_SIGNING_SECRET:
        return True  # 開発時は署名チェックをスキップ
    
    basestring = f"v0:{timestamp}:{request_body}"
    my_signature = 'v0=' + hmac.new(
        config.SLACK_SIGNING_SECRET.encode(),
        basestring.encode(),
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(my_signature, signature)

@app.route("/slack/events", methods=["POST"])
def slack_events():
    """
    Slackからのイベントを処理
    """
    try:
        # リクエストの検証
        request_body = request.get_data(as_text=True)
        timestamp = request.headers.get('X-Slack-Request-Timestamp', '')
        signature = request.headers.get('X-Slack-Signature', '')
        
        # タイムスタンプチェック（5分以内）
        if abs(time.time() - int(timestamp)) > 300:
            return jsonify({"error": "Request too old"}), 400
        
        # 署名検証
        if not verify_slack_signature(request_body, timestamp, signature):
            return jsonify({"error": "Invalid signature"}), 400
        
        data = request.get_json()
        
        # URL検証チャレンジ
        if "challenge" in data:
            return jsonify({"challenge": data["challenge"]})
        
        # イベント処理
        if "event" in data:
            event = data["event"]
            
            # メッセージイベントの処理
            if event["type"] == "message" and "subtype" not in event:
                # Bot自身のメッセージは無視
                if event.get("bot_id"):
                    return jsonify({"status": "ok"})
                
                user_id = event.get("user")
                channel_id = event.get("channel")
                text = event.get("text", "")
                
                # Bot宛てのメッセージか判定
                if is_bot_mention(text) or is_direct_message(channel_id):
                    # Bot mentionを除去
                    clean_text = clean_bot_mention(text)
                    
                    # 質問を処理
                    slack_client.handle_user_question(clean_text, user_id, channel_id)
        
        return jsonify({"status": "ok"})
        
    except Exception as e:
        print(f"Slack イベント処理エラー: {e}")
        return jsonify({"error": "Internal server error"}), 500

def is_bot_mention(text):
    """
    Bot宛てのメンションかどうか判定
    Args:
        text: メッセージテキスト
    Returns:
        bool: Bot宛てのメンションかどうか
    """
    return "<@" in text and "bot" in text.lower()

def is_direct_message(channel_id):
    """
    ダイレクトメッセージかどうか判定
    Args:
        channel_id: チャンネルID
    Returns:
        bool: ダイレクトメッセージかどうか
    """
    return channel_id.startswith("D")

def clean_bot_mention(text):
    """
    Bot mentionを除去してクリーンなテキストを返す
    Args:
        text: メッセージテキスト
    Returns:
        str: クリーンなテキスト
    """
    import re
    # Bot mentionを除去
    clean_text = re.sub(r'<@[A-Z0-9]+>', '', text)
    return clean_text.strip()

@app.route("/health", methods=["GET"])
def health_check():
    """
    ヘルスチェック
    """
    return jsonify({
        "status": "healthy",
        "slack_connected": slack_client.client is not None,
        "gemini_connected": slack_client.gemini_model is not None
    })

@app.route("/send-test", methods=["POST"])
def send_test_message():
    """
    テストメッセージを送信
    """
    try:
        data = request.get_json()
        message = data.get("message", "テストメッセージ")
        
        success = slack_client.send_simple_message(message)
        
        return jsonify({
            "success": success,
            "message": "メッセージ送信完了" if success else "メッセージ送信失敗"
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    print("=== Slack Bot サーバー起動 ===")
    print(f"Slack接続状態: {'✓' if slack_client.client else '✗'}")
    print(f"Gemini接続状態: {'✓' if slack_client.gemini_model else '✗'}")
    print("サーバーを起動しています...")
    
    # 開発用サーバーを起動
    app.run(
        host="0.0.0.0",
        port=int(os.environ.get("PORT", 5000)),
        debug=True
    )
