import json
import subprocess
import asyncio
from typing import Dict, Any, Optional
import config

class MCPClient:
    def __init__(self):
        self.server_process = None
        self.connected = False
    
    def start_server(self):
        """MCPサーバーを開始"""
        try:
            # mcp.jsonの設定を使用してサーバーを起動
            cmd = [
                "npx",
                "@google-ai/generativelanguage-mcp-server"
            ]
            
            env = {
                "GOOGLE_API_KEY": config.GOOGLE_API_KEY
            }
            
            # サーバープロセスを開始
            self.server_process = subprocess.Popen(
                cmd,
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            self.connected = True
            print("MCPサーバーを開始しました")
            
        except Exception as e:
            print(f"MCPサーバー開始エラー: {e}")
            self.connected = False
    
    def stop_server(self):
        """MCPサーバーを停止"""
        if self.server_process:
            self.server_process.terminate()
            self.server_process.wait()
            self.connected = False
            print("MCPサーバーを停止しました")
    
    def send_request(self, method: str, params: Dict[str, Any]) -> Optional[Dict]:
        """
        MCPサーバーにリクエストを送信
        Args:
            method: MCPメソッド
            params: パラメータ
        Returns:
            Dict: レスポンス
        """
        if not self.connected:
            print("MCPサーバーに接続されていません")
            return None
        
        try:
            request = {
                "jsonrpc": "2.0",
                "id": 1,
                "method": method,
                "params": params
            }
            
            request_json = json.dumps(request)
            
            # プロセスの標準入力に送信
            self.server_process.stdin.write(request_json.encode() + b'\n')
            self.server_process.stdin.flush()
            
            # レスポンスを読み取り
            response_line = self.server_process.stdout.readline()
            if response_line:
                response = json.loads(response_line.decode())
                return response
            
        except Exception as e:
            print(f"MCPリクエストエラー: {e}")
            return None
    
    def get_investment_advice(self, portfolio_data: Dict) -> Optional[str]:
        """
        Gemini APIを使用して投資アドバイスを取得
        Args:
            portfolio_data: ポートフォリオデータ
        Returns:
            str: 投資アドバイス
        """
        if not self.connected:
            print("MCPサーバーに接続されていません")
            return None
        
        try:
            # ポートフォリオ情報を文字列に変換
            portfolio_summary = self._format_portfolio_for_analysis(portfolio_data)
            
            # Geminiに送信するプロンプト
            prompt = f"""
            以下の株式ポートフォリオの分析と今後の売買戦略についてアドバイスをお願いします：

            {portfolio_summary}

            以下の点について分析してください：
            1. 現在のポートフォリオの評価
            2. リスク分析
            3. 今後の売買戦略の提案
            4. 注意すべき市場動向

            日本語で回答してください。
            """
            
            # Gemini APIを通じてアドバイスを取得
            response = self.send_request("generateContent", {
                "contents": [{"parts": [{"text": prompt}]}]
            })
            
            if response and "result" in response:
                return response["result"]["candidates"][0]["content"]["parts"][0]["text"]
            else:
                print("Gemini APIからの応答が不正です")
                return None
                
        except Exception as e:
            print(f"投資アドバイス取得エラー: {e}")
            return None
    
    def _format_portfolio_for_analysis(self, portfolio_data: Dict) -> str:
        """
        ポートフォリオデータを分析用の文字列に変換
        Args:
            portfolio_data: ポートフォリオデータ
        Returns:
            str: フォーマット済みの文字列
        """
        if not portfolio_data:
            return "ポートフォリオデータがありません"
        
        portfolio = portfolio_data.get('portfolio', [])
        stock_prices = portfolio_data.get('stock_prices', {})
        total_value = portfolio_data.get('total_value', 0)
        
        summary = f"総資産価値: ${total_value:,.2f}\n\n"
        summary += "保有銘柄一覧:\n"
        
        for stock in portfolio:
            symbol = stock['symbol']
            quantity = stock['quantity']
            
            if symbol in stock_prices:
                price_info = stock_prices[symbol]
                current_price = price_info['current_price']
                change_percent = price_info['change_percent']
                company_name = price_info['company_name']
                
                holding_value = current_price * quantity
                
                summary += f"- {company_name} ({symbol}): {quantity}株\n"
                summary += f"  現在価格: ${current_price:.2f} ({change_percent:+.2f}%)\n"
                summary += f"  保有価値: ${holding_value:,.2f}\n\n"
        
        return summary
    
    def __enter__(self):
        """コンテキストマネージャーの開始"""
        self.start_server()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """コンテキストマネージャーの終了"""
        self.stop_server()