#!/usr/bin/env python3
"""
開発環境用のSlack Bot起動スクリプト
ngrokと組み合わせて使用
"""

import os
import sys
import signal
import subprocess
import time
import threading
from flask import Flask, request, jsonify
from slack_client import SlackClient
import config

app = Flask(__name__)

# Slack クライアントの初期化
slack_client = SlackClient()

def verify_slack_signature(request_body, timestamp, signature):
    """
    Slackからのリクエストの署名を検証
    """
    if not config.SLACK_SIGNING_SECRET:
        print("⚠️  開発環境: 署名検証をスキップしています")
        return True
    
    import hashlib
    import hmac
    
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
        
        print(f"📨 Slackイベント受信: {len(request_body)}バイト")
        print(f"📝 リクエストボディ: {request_body[:200]}...")  # 最初の200文字のみ表示
        
        # 開発環境では署名検証を一時的に無効化
        print(f"🔐 リクエストヘッダー: Timestamp={timestamp}, Signature={signature[:20]}..." if signature else "署名なし")
        
        # 署名検証を一時的にスキップ（開発時のみ）
        # if timestamp and signature:
        #     if abs(time.time() - int(timestamp)) > 300:
        #         print("⚠️  タイムスタンプが古すぎます")
        #         return jsonify({"error": "Request too old"}), 400
        #     
        #     if not verify_slack_signature(request_body, timestamp, signature):
        #         print("⚠️  署名検証に失敗しました")
        #         return jsonify({"error": "Invalid signature"}), 400
        print("⚠️  開発環境: 署名検証をスキップしています")
        
        try:
            data = request.get_json()
            if not data:
                print("⚠️  JSONデータが空です")
                return jsonify({"error": "Empty JSON data"}), 400
        except Exception as json_error:
            print(f"❌ JSON解析エラー: {json_error}")
            return jsonify({"error": "Invalid JSON"}), 400
        
        # URL検証チャレンジ
        if "challenge" in data:
            print(f"🔗 URL検証チャレンジ: {data['challenge']}")
            return jsonify({"challenge": data["challenge"]})
        
        # イベント処理
        if "event" in data:
            event = data["event"]
            print(f"📋 イベントタイプ: {event.get('type')}")
            
            # メッセージイベントの処理
            if event["type"] == "message" and "subtype" not in event:
                # Bot自身のメッセージは無視
                if event.get("bot_id"):
                    print("🤖 Bot自身のメッセージをスキップ")
                    return jsonify({"status": "ok"})
                
                user_id = event.get("user")
                channel_id = event.get("channel")
                text = event.get("text", "")
                
                print(f"💬 メッセージ受信: {text[:50]}...")
                
                # Bot宛てのメッセージか判定
                if is_bot_mention(text) or is_direct_message(channel_id):
                    # Bot mentionを除去
                    clean_text = clean_bot_mention(text)
                    print(f"🎯 Bot宛てメッセージを処理: {clean_text[:30]}...")
                    
                    # 質問を処理
                    slack_client.handle_user_question(clean_text, user_id, channel_id)
                else:
                    print("ℹ️  Bot宛て以外のメッセージをスキップ")
        
        return jsonify({"status": "ok"})
        
    except Exception as e:
        print(f"❌ Slack イベント処理エラー: {e}")
        return jsonify({"error": "Internal server error"}), 500

def is_bot_mention(text):
    """Bot宛てのメンションかどうか判定"""
    return "<@" in text

def is_direct_message(channel_id):
    """ダイレクトメッセージかどうか判定"""
    return channel_id.startswith("D")

def clean_bot_mention(text):
    """Bot mentionを除去してクリーンなテキストを返す"""
    import re
    clean_text = re.sub(r'<@[A-Z0-9]+>', '', text)
    return clean_text.strip()

@app.route("/health", methods=["GET"])
def health_check():
    """ヘルスチェック"""
    return jsonify({
        "status": "healthy",
        "environment": "development",
        "slack_connected": slack_client.client is not None,
        "gemini_connected": slack_client.gemini_model is not None,
        "ngrok_info": "Use ngrok http 5000 to expose this server",
        "endpoints": {
            "events": "/slack/events - Slack Event Subscriptions",
            "commands": "/slack/commands - Slack Slash Commands",
            "health": "/health - Health check",
            "test": "/send-test - Test message"
        }
    })

@app.route("/send-test", methods=["POST"])
def send_test_message():
    """テストメッセージを送信"""
    try:
        data = request.get_json() or {}
        message = data.get("message", "🧪 テストメッセージ from 開発環境")
        
        success = slack_client.send_simple_message(message)
        
        return jsonify({
            "success": success,
            "message": "メッセージ送信完了" if success else "メッセージ送信失敗"
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/", methods=["GET"])
def index():
    """開発用インデックスページ"""
    return """
    <h1>🚀 投資アドバイス Slack Bot - 開発環境</h1>
    <p>✅ サーバーは正常に稼働中です</p>
    <h2>エンドポイント:</h2>
    <ul>
        <li><code>POST /slack/events</code> - Slack Event Subscriptions (メンション)</li>
        <li><code>POST /slack/commands</code> - Slack Slash Commands (スラッシュコマンド)</li>
        <li><code>GET /health</code> - ヘルスチェック</li>
        <li><code>POST /send-test</code> - テストメッセージ送信</li>
    </ul>
    <h2>使い方:</h2>
    <ul>
        <li>💬 <strong>メンション:</strong> @bot 質問内容</li>
        <li>⚡ <strong>スラッシュコマンド:</strong> /投資 質問内容</li>
    </ul>
    <h2>ngrok設定:</h2>
    <p>以下のコマンドでngrokを起動してください:</p>
    <pre>ngrok http 5000</pre>
    <p>そのURLをSlack Appの以下に設定してください:</p>
    <ul>
        <li>Event Subscriptions → Request URL: https://your-ngrok-url.ngrok.io/slack/events</li>
        <li>Slash Commands → Request URL: https://your-ngrok-url.ngrok.io/slack/commands</li>
    </ul>
    """

@app.route("/slack/commands", methods=["POST"])
def slack_commands():
    """
    Slackからのスラッシュコマンドを処理
    """
    try:
        # フォームデータからパラメータを取得
        command = request.form.get('command', '')
        text = request.form.get('text', '')
        user_id = request.form.get('user_id', '')
        channel_id = request.form.get('channel_id', '')
        user_name = request.form.get('user_name', '')
        
        print(f"🔧 スラッシュコマンド受信:")
        print(f"   コマンド: {command}")
        print(f"   テキスト: {text}")
        print(f"   ユーザー: {user_name} ({user_id})")
        print(f"   チャンネル: {channel_id}")
        
        # 簡単な応答を返す
        if text.strip():
            # ユーザーからの質問を処理
            print(f"🎯 質問を処理中: {text[:50]}...")
            
            # バックグラウンドで質問を処理（Slackの3秒制限を回避）
            def process_question_async():
                try:
                    slack_client.handle_user_question(text, user_id, channel_id)
                except Exception as e:
                    print(f"❌ 非同期質問処理エラー: {e}")
            
            # 別スレッドで実行
            import threading
            thread = threading.Thread(target=process_question_async)
            thread.daemon = True
            thread.start()
            
            return jsonify({
                "response_type": "in_channel",
                "text": f"🤖 質問を受け付けました: 「{text[:100]}...」\n💭 AI分析中です。少々お待ちください..."
            })
        else:
            return jsonify({
                "response_type": "ephemeral",
                "text": "💡 使い方: `/投資 質問内容` で投資に関する質問ができます\n例: `/投資 トヨタ株の今後の見通しは？`"
            })
            
    except Exception as e:
        print(f"❌ スラッシュコマンド処理エラー: {e}")
        return jsonify({
            "response_type": "ephemeral",
            "text": "⚠️ エラーが発生しました。しばらくしてから再度お試しください。"
        }), 500

if __name__ == "__main__":
    print("=" * 50)
    print("🚀 投資アドバイス Slack Bot - 開発環境")
    print("=" * 50)
    print(f"Slack接続状態: {'✅' if slack_client.client else '❌'}")
    print(f"Gemini接続状態: {'✅' if slack_client.gemini_model else '❌'}")
    print()
    print("📋 次の手順:")
    print("1. 別ターミナルで 'ngrok http 5000' を実行")
    print("2. ngrokのHTTPS URLをSlack AppのWebhook URLに設定")
    print("3. Slackでテストメッセージを送信")
    print()
    print("🌐 サーバーを起動しています...")
    
    # 開発用サーバーを起動
    app.run(
        host="0.0.0.0",
        port=int(os.environ.get("PORT", 5000)),
        debug=True,
        use_reloader=False  # ngrokとの併用時は無効にする
    )
