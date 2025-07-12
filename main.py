#!/usr/bin/env python3
"""
株式投資アドバイスアプリケーション
- Google Sheetsから保有株式リストを取得
- 株価情報を取得
- MCPを通じてGemini APIで投資アドバイスを取得
"""

import sys
from dotenv import load_dotenv
import os
from data_fetcher import DataFetcher
from analyzer import PortfolioAnalyzer
from mcp_client import MCPClient
from slack_client import SlackClient

load_dotenv()

def main():
    """メイン処理"""
    print("=== 株式投資アドバイスアプリケーション ===")
    
    # 環境変数チェック
    required_env_vars = ['GOOGLE_SHEETS_CREDENTIALS_PATH', 'SPREADSHEET_ID', 'GOOGLE_API_KEY']
    missing_vars = []
    
    for var in required_env_vars:
        if not os.getenv(var):
            missing_vars.append(var)
    
    if missing_vars:
        print(f"エラー: 以下の環境変数が設定されていません: {', '.join(missing_vars)}")
        print("\n.envファイルに以下の設定を追加してください:")
        print("GOOGLE_SHEETS_CREDENTIALS_PATH=path/to/your/credentials.json")
        print("SPREADSHEET_ID=your_spreadsheet_id")
        print("GOOGLE_API_KEY=your_gemini_api_key")
        return 1
    
    try:
        # データフェッチャーの初期化
        print("\n1. データフェッチャーを初期化中...")
        data_fetcher = DataFetcher()
        
        # ポートフォリオと株価情報の取得
        print("\n2. ポートフォリオと株価情報を取得中...")
        portfolio_data = data_fetcher.get_portfolio_with_prices()
        
        if not portfolio_data:
            print("エラー: ポートフォリオデータの取得に失敗しました")
            return 1
        
        # 基本分析の実行
        print("\n3. ポートフォリオ分析を実行中...")
        analyzer = PortfolioAnalyzer()
        analysis = analyzer.analyze_portfolio(portfolio_data)
        
        # 分析レポートの表示
        print("\n4. 分析レポートを生成中...")
        report = analyzer.generate_report(analysis)
        print(report)
        
        # Gemini APIによる投資アドバイスの取得
        print("\n5. AI投資アドバイスを取得中...")
        advice = None
        try:
            with MCPClient() as mcp_client:
                advice = mcp_client.get_investment_advice(portfolio_data)
                
                if advice:
                    print("\n=== AI投資アドバイス ===")
                    print(advice)
                else:
                    print("投資アドバイスの取得に失敗しました")
                    
        except Exception as e:
            print(f"MCP接続エラー: {e}")
            print("注意: Gemini APIへの接続に失敗しました。基本分析のみ実行されました。")
        
        # Slack通知の送信
        print("\n6. Slack通知を送信中...")
        try:
            slack_client = SlackClient()
            if slack_client.client:
                # 投資アドバイスとレポートをSlackに送信
                success = slack_client.send_investment_advice(portfolio_data, report)
                if success:
                    print("Slack通知送信成功")
                    if advice:
                        # AI投資アドバイスも送信
                        slack_client.send_simple_message(f"🤖 *AI投資アドバイス*\n```{advice}```")
                else:
                    print("Slack通知送信失敗")
            else:
                print("Slack通知をスキップ（設定未完了）")
        except Exception as e:
            print(f"Slack通知エラー: {e}")
        
        print("\n=== 処理完了 ===")
        return 0
        
    except KeyboardInterrupt:
        print("\n\n処理が中断されました")
        return 1
    except Exception as e:
        print(f"\n予期しないエラーが発生しました: {e}")
        return 1

def show_help():
    """ヘルプメッセージを表示"""
    help_text = """
株式投資アドバイスアプリケーション

使用方法:
  python main.py        - メイン処理を実行
  python main.py --help - このヘルプを表示

必要な環境変数:
  GOOGLE_SHEETS_CREDENTIALS_PATH - Google Sheetsサービスアカウントの認証情報ファイルパス
  SPREADSHEET_ID                 - 保有株式リストが記載されたスプレッドシートのID
  GOOGLE_API_KEY                 - Gemini APIキー

スプレッドシートの形式:
  - 'symbol' カラム: 株式銘柄コード (例: AAPL, GOOGL)
  - 'quantity' カラム: 保有数量

例:
  python main.py
"""
    print(help_text)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] in ['--help', '-h']:
        show_help()
        sys.exit(0)
    
    sys.exit(main())