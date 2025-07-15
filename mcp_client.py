import json
import google.generativeai as genai
from typing import Dict, Any, Optional
import config

class MCPClient:
    def __init__(self):
        self.connected = False
        self.model = None
    
    def start_server(self):
        """Gemini APIクライアントを初期化"""
        try:
            # Gemini APIの設定
            genai.configure(api_key=config.GOOGLE_API_KEY)
            self.model = genai.GenerativeModel('gemini-2.5-flash')
            self.connected = True
            print("Gemini APIクライアントを初期化しました")
            
        except Exception as e:
            print(f"Gemini API初期化エラー: {e}")
            self.connected = False
    
    def stop_server(self):
        """クライアントを停止"""
        self.connected = False
        self.model = None
        print("Gemini APIクライアントを停止しました")
    
    def get_investment_advice(self, portfolio_data: Dict, execution_type: str = 'daily') -> Optional[str]:
        """
        Gemini APIを使用して投資アドバイスを取得
        Args:
            portfolio_data: ポートフォリオデータ
            execution_type: 実行タイプ（daily/monthly）
        Returns:
            str: 投資アドバイス
        """
        if not self.connected or not self.model:
            print("Gemini APIクライアントに接続されていません")
            return None
        
        try:
            # ポートフォリオ情報を文字列に変換
            portfolio_summary = self._format_portfolio_for_analysis(portfolio_data)
            
            # 実行タイプに応じてプロンプトを変更
            if execution_type == 'daily':
                prompt = f"""
                以下の株式ポートフォリオの日次売買タイミング分析をお願いします：

                {portfolio_summary}

                【日次分析の焦点】
                以下の点について分析してください：
                1. 保有中の各銘柄の短期的な売買タイミング
                2. 買い増しするべき銘柄とその理由
                3. 売却を検討すべき銘柄とその理由
                4. 今日の市場動向と明日への影響
                5. 短期的なリスク要因

                【回答形式】
                - 各銘柄について「買い増し」「売却」「保有継続」のいずれかの推奨アクションを明記
                - 具体的な売買タイミングの根拠を提示
                - 短期的な価格変動要因を重視した分析

                日本語で回答してください。
                """
            else:  # monthly
                prompt = f"""
                以下の株式ポートフォリオの月次戦略分析をお願いします：

                {portfolio_summary}

                【月次分析の焦点】
                以下の点について分析してください：
                1. 現在のポートフォリオの総合評価
                2. 長期的なリスク分析
                3. ポートフォリオ全体の最適化提案
                4. 新規投資候補の提案
                5. 中長期的な市場見通し

                【回答形式】
                - ポートフォリオ全体の戦略的な見直し提案
                - 長期投資の観点からの評価
                - 分散投資の観点からの改善提案

                日本語で回答してください。
                """
            
            # Gemini APIを通じてアドバイスを取得
            response = self.model.generate_content(prompt)
            
            if response and response.text:
                return response.text
            else:
                print("Gemini APIからの応答が空です")
                return None
                
        except Exception as e:
            print(f"投資アドバイス取得エラー: {e}")
            return None
    
    def _format_portfolio_for_analysis(self, portfolio_data: Dict) -> str:
        """
        ポートフォリオデータを分析用の文字列に変換（円換算対応）
        Args:
            portfolio_data: ポートフォリオデータ
        Returns:
            str: フォーマット済みの文字列
        """
        if not portfolio_data:
            return "ポートフォリオデータがありません"
        
        portfolio = portfolio_data.get('portfolio', [])
        stock_prices = portfolio_data.get('stock_prices', {})
        total_value_jpy = portfolio_data.get('total_value_jpy_converted', 0)
        total_value_usd = portfolio_data.get('total_value_usd', 0)
        usd_jpy_rate = portfolio_data.get('usd_jpy_rate', 150.0)
        
        summary = f"総資産価値: ¥{total_value_jpy:,.0f}\n"
        summary += f"　（米国株部分: ${total_value_usd:,.2f}）\n"
        summary += f"USD/JPY為替レート: {usd_jpy_rate:.2f}\n\n"
        summary += "保有銘柄一覧:\n"
        
        for stock in portfolio:
            symbol = stock['symbol']
            quantity = stock['quantity']
            
            if symbol in stock_prices:
                price_info = stock_prices[symbol]
                current_price = price_info['current_price']
                change_percent = price_info['change_percent']
                company_name = price_info['company_name']
                currency = price_info.get('currency', 'USD')
                
                holding_value_original = current_price * quantity
                
                if currency == 'JPY':
                    holding_value_jpy = holding_value_original
                    price_display = f"¥{current_price:,.0f}"
                    value_display = f"¥{holding_value_jpy:,.0f}"
                else:
                    holding_value_jpy = holding_value_original * usd_jpy_rate
                    price_display = f"${current_price:.2f} (¥{current_price * usd_jpy_rate:,.0f})"
                    value_display = f"¥{holding_value_jpy:,.0f} (${holding_value_original:,.2f})"
                
                summary += f"- {company_name} ({symbol}): {quantity}株\n"
                summary += f"  現在価格: {price_display} ({change_percent:+.2f}%)\n"
                summary += f"  保有価値: {value_display}\n\n"
        
        return summary
    
    def __enter__(self):
        """コンテキストマネージャーの開始"""
        self.start_server()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """コンテキストマネージャーの終了"""
        self.stop_server()
