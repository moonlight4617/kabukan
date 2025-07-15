#!/usr/bin/env python3
"""
AWS Lambda用の投資アドバイスアプリケーション
EventBridgeから定期実行され、Slack通知を送信
"""

import json
import os
import boto3
from typing import Dict, Any

# 必要なモジュールをインポート
from data_fetcher import DataFetcher
from analyzer import PortfolioAnalyzer
from mcp_client import MCPClient
from slack_client import SlackClient

def lambda_handler(event, context):
    """
    Lambda関数のメインハンドラー
    
    Args:
        event: EventBridgeからのイベント（定期実行時は空のオブジェクト）
        context: Lambdaランタイムコンテキスト
    
    Returns:
        dict: 実行結果
    """
    
    # 実行タイプを判別（日次 or 月次）
    execution_type = event.get('execution_type', 'daily')  # デフォルトは日次
    
    print(f"=== AWS Lambda - 投資アドバイス自動通知 ({execution_type}) ===")
    print(f"Event: {json.dumps(event)}")
    print(f"Request ID: {context.aws_request_id}")
    print(f"実行タイプ: {execution_type}")
    
    # 環境変数チェック
    required_env_vars = [
        'GOOGLE_SHEETS_CREDENTIALS_PATH', 
        'SPREADSHEET_ID', 
        'GOOGLE_API_KEY',
        'SLACK_BOT_TOKEN',
        'SLACK_CHANNEL'
    ]
    missing_vars = []
    
    for var in required_env_vars:
        if not os.environ.get(var):
            missing_vars.append(var)
    
    if missing_vars:
        error_msg = f"環境変数が設定されていません: {', '.join(missing_vars)}"
        print(f"❌ エラー: {error_msg}")
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': error_msg,
                'missing_vars': missing_vars
            }, ensure_ascii=False)
        }
    
    try:
        # Google認証情報の取得（S3からダウンロードまたは環境変数から）
        credentials_path = prepare_google_credentials()
        
        # データフェッチャーの初期化
        print("\n1️⃣ データフェッチャーを初期化中...")
        data_fetcher = DataFetcher()
        
        # ポートフォリオと株価情報の取得
        print("\n2️⃣ ポートフォリオと株価情報を取得中...")
        portfolio_data = data_fetcher.get_portfolio_with_prices()
        
        if not portfolio_data:
            error_msg = "ポートフォリオデータの取得に失敗"
            print(f"❌ エラー: {error_msg}")
            return {
                'statusCode': 500,
                'body': json.dumps({'error': error_msg}, ensure_ascii=False)
            }
        
        print(f"✅ ポートフォリオ取得完了: {len(portfolio_data)}銘柄")
        
        # 基本分析の実行
        print("\n3️⃣ ポートフォリオ分析を実行中...")
        analyzer = PortfolioAnalyzer()
        analysis = analyzer.analyze_portfolio(portfolio_data)
        
        # 分析レポートの生成
        print("\n4️⃣ 分析レポートを生成中...")
        report = analyzer.generate_report(analysis)
        print("✅ 分析レポート生成完了")
        
        # Gemini APIによる投資アドバイスの取得
        print("\n5️⃣ AI投資アドバイスを取得中...")
        advice = None
        try:
            with MCPClient() as mcp_client:
                advice = mcp_client.get_investment_advice(portfolio_data, execution_type)
                
                if advice:
                    print("✅ AI投資アドバイス取得完了")
                else:
                    print("⚠️ 投資アドバイスの取得に失敗")
                    
        except Exception as e:
            print(f"⚠️ Gemini API接続エラー: {e}")
            print("注意: AI投資アドバイスの取得に失敗しました。基本分析のみ送信されます。")
        
        # Slack通知の送信
        print("\n6️⃣ Slack通知を送信中...")
        notification_result = send_slack_notification(portfolio_data, report, advice, execution_type)
        
        # 結果のまとめ
        result = {
            'statusCode': 200,
            'body': json.dumps({
                'message': '投資アドバイス通知完了',
                'portfolio_count': len(portfolio_data),
                'ai_advice_available': advice is not None,
                'slack_notification': notification_result,
                'timestamp': context.get_remaining_time_in_millis()
            }, ensure_ascii=False)
        }
        
        print("\n✅ 処理完了")
        print(f"実行時間: {1000 - context.get_remaining_time_in_millis()}ms")
        
        return result
        
    except Exception as e:
        error_msg = f"予期しないエラー: {str(e)}"
        print(f"❌ {error_msg}")
        
        # エラー時もSlackに通知（可能であれば）
        try:
            slack_client = SlackClient()
            if slack_client.client:
                slack_client.send_simple_message(f"⚠️ 投資アドバイス自動通知でエラーが発生しました\n```{error_msg}```")
        except:
            print("Slackエラー通知も失敗")
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': error_msg,
                'request_id': context.aws_request_id
            }, ensure_ascii=False)
        }

def prepare_google_credentials() -> str:
    """
    Google認証情報を準備
    S3からダウンロードまたは環境変数から取得
    
    Returns:
        str: 認証情報ファイルのパス
    """
    credentials_path = os.environ.get('GOOGLE_SHEETS_CREDENTIALS_PATH', '/tmp/credentials.json')
    
    # S3から認証情報をダウンロードする場合
    s3_bucket = os.environ.get('CREDENTIALS_S3_BUCKET')
    s3_key = os.environ.get('CREDENTIALS_S3_KEY')
    
    if s3_bucket and s3_key:
        print(f"📥 S3から認証情報をダウンロード中: s3://{s3_bucket}/{s3_key}")
        try:
            s3 = boto3.client('s3')
            s3.download_file(s3_bucket, s3_key, credentials_path)
            print("✅ S3からの認証情報ダウンロード完了")
        except Exception as e:
            print(f"❌ S3ダウンロードエラー: {e}")
            raise
    
    # 環境変数として直接JSONが設定されている場合
    elif os.environ.get('GOOGLE_CREDENTIALS_JSON'):
        print("📝 環境変数から認証情報を作成中...")
        with open(credentials_path, 'w') as f:
            f.write(os.environ.get('GOOGLE_CREDENTIALS_JSON'))
        print("✅ 環境変数からの認証情報作成完了")
    
    return credentials_path

def send_slack_notification(portfolio_data: list, report: str, advice: str = None, execution_type: str = 'daily') -> Dict[str, Any]:
    """
    Slack通知を送信
    
    Args:
        portfolio_data: ポートフォリオデータ
        report: 分析レポート
        advice: AI投資アドバイス（オプション）
        execution_type: 実行タイプ（daily/monthly）
    
    Returns:
        dict: 送信結果
    """
    try:
        slack_client = SlackClient()
        if not slack_client.client:
            return {
                'success': False,
                'error': 'Slack接続失敗'
            }
        
        # 基本レポートの送信
        report_success = slack_client.send_investment_advice(portfolio_data, report, execution_type)
        
        # AI投資アドバイスの送信（ある場合）
        advice_success = True
        if advice:
            # Slackメッセージの文字数制限（4000文字）を考慮して分割
            max_length = 3000
            if len(advice) > max_length:
                advice_parts = [advice[i:i+max_length] for i in range(0, len(advice), max_length)]
                for i, part in enumerate(advice_parts):
                    part_success = slack_client.send_simple_message(
                        f"🤖 **AI投資アドバイス (Part {i+1}/{len(advice_parts)})**\n```{part}```"
                    )
                    if not part_success:
                        advice_success = False
            else:
                advice_success = slack_client.send_simple_message(
                    f"🤖 **AI投資アドバイス**\n```{advice}```"
                )
        
        result = {
            'success': report_success and advice_success,
            'report_sent': report_success,
            'advice_sent': advice_success if advice else None,
            'advice_available': advice is not None
        }
        
        if result['success']:
            print("✅ Slack通知送信成功")
        else:
            print("❌ Slack通知送信失敗")
        
        return result
        
    except Exception as e:
        error_msg = f"Slack通知エラー: {e}"
        print(f"❌ {error_msg}")
        return {
            'success': False,
            'error': error_msg
        }

def health_check(event, context):
    """
    ヘルスチェック用のLambda関数
    """
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Lambda function is healthy',
            'timestamp': context.aws_request_id,
            'environment_vars_present': {
                'GOOGLE_SHEETS_CREDENTIALS_PATH': bool(os.environ.get('GOOGLE_SHEETS_CREDENTIALS_PATH')),
                'SPREADSHEET_ID': bool(os.environ.get('SPREADSHEET_ID')),
                'GOOGLE_API_KEY': bool(os.environ.get('GOOGLE_API_KEY')),
                'SLACK_BOT_TOKEN': bool(os.environ.get('SLACK_BOT_TOKEN')),
                'SLACK_CHANNEL': bool(os.environ.get('SLACK_CHANNEL'))
            }
        }, ensure_ascii=False)
    }
