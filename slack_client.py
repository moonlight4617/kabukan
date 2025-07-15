import os
import json
from typing import Optional, Dict, Any
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError
import google.generativeai as genai
import config

class SlackClient:
    def __init__(self):
        self.client = None
        self.gemini_model = None
        self._setup_slack_client()
        self._setup_gemini_client()
    
    def _setup_slack_client(self):
        """Slack APIクライアントの設定"""
        try:
            if not config.SLACK_BOT_TOKEN:
                print("Slack Bot Tokenが設定されていません")
                return
            
            self.client = WebClient(token=config.SLACK_BOT_TOKEN)
            
            # Bot接続テスト
            response = self.client.auth_test()
            print(f"Slack Bot接続成功: {response['user']}")
            
        except SlackApiError as e:
            print(f"Slack接続エラー: {e.response['error']}")
            self.client = None
        except Exception as e:
            print(f"Slack設定エラー: {e}")
            self.client = None
    
    def _setup_gemini_client(self):
        """Gemini APIクライアントの設定"""
        try:
            genai.configure(api_key=config.GOOGLE_API_KEY)
            self.gemini_model = genai.GenerativeModel('gemini-1.5-flash')
            print("Gemini APIクライアント設定完了")
        except Exception as e:
            print(f"Gemini API設定エラー: {e}")
            self.gemini_model = None
    
    def send_investment_advice(self, portfolio_data: Dict, analysis_report: str, execution_type: str = 'daily') -> bool:
        """
        投資アドバイスをSlackに送信
        Args:
            portfolio_data: ポートフォリオデータ
            analysis_report: 分析レポート
            execution_type: 実行タイプ（daily/monthly）
        Returns:
            bool: 送信成功したかどうか
        """
        if not self.client:
            print("Slackクライアントが初期化されていません")
            return False
        
        try:
            # ポートフォリオサマリーを作成
            portfolio_summary = self._format_portfolio_summary(portfolio_data)
            
            # メッセージを構築
            message = self._build_investment_message(portfolio_summary, analysis_report, execution_type)
            
            # Slackに送信
            response = self.client.chat_postMessage(
                channel=config.SLACK_CHANNEL,
                text="📊 投資アドバイスレポート",
                blocks=message
            )
            
            print(f"Slack投資アドバイス送信成功: {response['ts']}")
            return True
            
        except SlackApiError as e:
            print(f"Slack送信エラー: {e.response['error']}")
            return False
        except Exception as e:
            print(f"投資アドバイス送信エラー: {e}")
            return False
    
    def _format_portfolio_summary(self, portfolio_data: Dict) -> str:
        """ポートフォリオサマリーを作成（円換算対応）"""
        if not portfolio_data:
            return "ポートフォリオデータがありません"
        
        portfolio = portfolio_data.get('portfolio', [])
        stock_prices = portfolio_data.get('stock_prices', {})
        total_value_jpy = portfolio_data.get('total_value_jpy_converted', 0)
        total_value_usd = portfolio_data.get('total_value_usd', 0)
        usd_jpy_rate = portfolio_data.get('usd_jpy_rate', 150.0)
        
        summary = f"💰 総資産価値: ¥{total_value_jpy:,.0f}\n"
        summary += f"　（米国株部分: ${total_value_usd:,.2f}）\n"
        summary += f"💱 USD/JPY: {usd_jpy_rate:.2f}\n"
        summary += f"📈 保有銘柄数: {len(portfolio)}銘柄\n\n"
        
        for stock in portfolio:
            symbol = stock['symbol']
            quantity = stock['quantity']
            
            if symbol in stock_prices:
                price_info = stock_prices[symbol]
                current_price = price_info['current_price']
                change_percent = price_info['change_percent']
                company_name = price_info['company_name']
                currency = price_info.get('currency', 'USD')
                
                emoji = "📈" if change_percent > 0 else "📉" if change_percent < 0 else "➡️"
                summary += f"{emoji} {company_name} ({symbol}): {quantity}株\n"
                
                if currency == 'JPY':
                    summary += f"   ¥{current_price:,.0f} ({change_percent:+.2f}%)\n"
                else:
                    summary += f"   ${current_price:.2f} (¥{current_price * usd_jpy_rate:,.0f}) ({change_percent:+.2f}%)\n"
        
        return summary
    
    def _build_investment_message(self, portfolio_summary: str, analysis_report: str, execution_type: str = 'daily') -> list:
        """Slack用のメッセージブロックを構築"""
        execution_emoji = "📅" if execution_type == 'daily' else "📆"
        execution_name = "日次" if execution_type == 'daily' else "月次"
        
        blocks = [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"{execution_emoji} {execution_name}投資アドバイスレポート"
                }
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*ポートフォリオサマリー*\n```{portfolio_summary}```"
                }
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*分析レポート*\n```{analysis_report}```"
                }
            },
            {
                "type": "context",
                "elements": [
                    {
                        "type": "mrkdwn",
                        "text": "💡 具体的な質問があれば、/stock で話しかけてください"
                    }
                ]
            }
        ]
        
        return blocks
    
    def handle_user_question(self, question: str, user_id: str, channel_id: str) -> bool:
        """
        ユーザーからの質問をGeminiに送信し、回答をSlackに返す
        Args:
            question: 質問内容
            user_id: ユーザーID
            channel_id: チャンネルID
        Returns:
            bool: 処理成功したかどうか
        """
        if not self.client or not self.gemini_model:
            return False
        
        try:
            # 投資関連の質問であることを明確にするプロンプト
            enhanced_prompt = f"""
            あなたは投資アドバイザーです。以下の質問に日本語で回答してください。
            質問が投資や株式に関係ない場合は、「投資関連の質問のみお答えできます」と返答してください。
            
            質問: {question}
            """
            
            # Geminiに質問を送信
            response = self.gemini_model.generate_content(enhanced_prompt)
            answer = response.text if response and response.text else "申し訳ございません。回答を生成できませんでした。"
            
            # Slackに回答を送信
            self.client.chat_postMessage(
                channel=channel_id,
                text=f"<@{user_id}> さんのご質問への回答:\n```{answer}```",
                thread_ts=None
            )
            
            print(f"ユーザー質問への回答送信完了: {user_id}")
            return True
            
        except Exception as e:
            print(f"ユーザー質問処理エラー: {e}")
            # エラーメッセージをSlackに送信
            try:
                self.client.chat_postMessage(
                    channel=channel_id,
                    text=f"<@{user_id}> 申し訳ございません。処理中にエラーが発生しました。"
                )
            except:
                pass
            return False
    
    def send_simple_message(self, message: str, channel: str = None) -> bool:
        """
        シンプルなメッセージをSlackに送信
        Args:
            message: メッセージ内容
            channel: チャンネル（省略時はデフォルト）
        Returns:
            bool: 送信成功したかどうか
        """
        if not self.client:
            return False
        
        try:
            self.client.chat_postMessage(
                channel=channel or config.SLACK_CHANNEL,
                text=message
            )
            return True
        except Exception as e:
            print(f"メッセージ送信エラー: {e}")
            return False
