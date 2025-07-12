#!/usr/bin/env python3
"""
開発環境用メインアプリケーション
投資アドバイスの取得とSlack通知を行う
"""

import sys
import os
from dotenv import load_dotenv
load_dotenv()

from data_fetcher import DataFetcher
from analyzer import PortfolioAnalyzer
from mcp_client import MCPClient
from slack_client import SlackClient

def main():
    """メイン処理"""
    print("=" * 50)
    print("📊 投資アドバイスアプリケーション - 開発環境")
    print("=" * 50)
    
    # 環境変数チェック
    required_env_vars = ['GOOGLE_SHEETS_CREDENTIALS_PATH', 'SPREADSHEET_ID', 'GOOGLE_API_KEY']
    missing_vars = []
    
    for var in required_env_vars:
        if not os.getenv(var):
            missing_vars.append(var)
    
    if missing_vars:
        print(f"❌ エラー: 以下の環境変数が設定されていません: {', '.join(missing_vars)}")
        print("\n.envファイルに以下の設定を追加してください:")
        print("GOOGLE_SHEETS_CREDENTIALS_PATH=./credentials_config/credentials.json")
        print("SPREADSHEET_ID=your_spreadsheet_id")
        print("GOOGLE_API_KEY=your_gemini_api_key")
        return 1
    
    try:
        # データフェッチャーの初期化
        print("\n1️⃣ データフェッチャーを初期化中...")
        data_fetcher = DataFetcher()
        
        # ポートフォリオと株価情報の取得
        print("\n2️⃣ ポートフォリオと株価情報を取得中...")
        portfolio_data = data_fetcher.get_portfolio_with_prices()
        
        if not portfolio_data:
            print("❌ エラー: ポートフォリオデータの取得に失敗しました")
            return 1
        
        # 基本分析の実行
        print("\n3️⃣ ポートフォリオ分析を実行中...")
        analyzer = PortfolioAnalyzer()
        analysis = analyzer.analyze_portfolio(portfolio_data)
        
        # 分析レポートの表示
        print("\n4️⃣ 分析レポートを生成中...")
        report = analyzer.generate_report(analysis)
        print("\n" + "="*50)
        print("📈 分析レポート")
        print("="*50)
        print(report)
        
        # Gemini APIによる投資アドバイスの取得
        print("\n5️⃣ AI投資アドバイスを取得中...")
        advice = None
        try:
            with MCPClient() as mcp_client:
                advice = mcp_client.get_investment_advice(portfolio_data)
                
                if advice:
                    print("\n" + "="*50)
                    print("🤖 AI投資アドバイス")
                    print("="*50)
                    print(advice)
                else:
                    print("⚠️ 投資アドバイスの取得に失敗しました")
                    
        except Exception as e:
            print(f"❌ Gemini API接続エラー: {e}")
            print("⚠️ 注意: AI投資アドバイスの取得に失敗しました。基本分析のみ実行されました。")
        
        # Slack通知の送信
        print("\n6️⃣ Slack通知を送信中...")
        try:
            slack_client = SlackClient()
            if slack_client.client:
                # 投資アドバイスとレポートをSlackに送信
                success = slack_client.send_investment_advice(portfolio_data, report)
                if success:
                    print("✅ Slack通知送信成功")
                    if advice:
                        # AI投資アドバイスも送信
                        slack_client.send_simple_message(f"🤖 **AI投資アドバイス**\n```{advice[:1000]}...```")
                        print("✅ AI投資アドバイスもSlackに送信しました")
                else:
                    print("❌ Slack通知送信失敗")
            else:
                print("⚠️ Slack通知をスキップ（設定未完了または開発環境）")
                print("💡 ヒント: Slack Botサーバーを起動してテストしてください")
                print("   python slack_bot_dev.py")
        except Exception as e:
            print(f"❌ Slack通知エラー: {e}")
        
        print("\n" + "="*50)
        print("✅ 処理完了")
        print("="*50)
        print("💡 開発環境での次のステップ:")
        print("1. Slack Botサーバーを起動: python slack_bot_dev.py")
        print("2. ngrokでトンネル作成: ./start_ngrok.sh")
        print("3. Slack AppにngrokのURLを設定")
        print("4. SlackでBotにメンション(@bot 質問内容)")
        return 0
        
    except KeyboardInterrupt:
        print("\n\n⚠️ 処理が中断されました")
        return 1
    except Exception as e:
        print(f"\n❌ 予期しないエラーが発生しました: {e}")
        import traceback
        traceback.print_exc()
        return 1

def show_help():
    """ヘルプメッセージを表示"""
    help_text = """
📊 投資アドバイスアプリケーション - 開発環境

使用方法:
  python main_dev.py        - メイン処理を実行
  python main_dev.py --help - このヘルプを表示

必要な環境変数:
  GOOGLE_SHEETS_CREDENTIALS_PATH - Google Sheetsサービスアカウントの認証情報ファイルパス
  SPREADSHEET_ID                 - 保有株式リストが記載されたスプレッドシートのID
  GOOGLE_API_KEY                 - Gemini APIキー

Slack Bot開発環境:
  SLACK_BOT_TOKEN               - Slack Bot Token (xoxb-...)
  SLACK_SIGNING_SECRET          - Slack Signing Secret
  SLACK_CHANNEL                 - 通知チャンネル (#investment-advice)

開発ワークフロー:
  1. python main_dev.py                    # 基本的なポートフォリオ分析実行
  2. python slack_bot_dev.py               # Slack Botサーバー起動
  3. ./start_ngrok.sh                      # ngrokでトンネル作成
  4. Slack AppにngrokのURLを設定
  5. SlackでBotとやり取り

例:
  python main_dev.py
"""
    print(help_text)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] in ['--help', '-h']:
        show_help()
        sys.exit(0)
    
    sys.exit(main())
