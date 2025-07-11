import gspread
import yfinance as yf
import pandas as pd
from google.oauth2.service_account import Credentials
from typing import List, Dict, Optional
import config

class DataFetcher:
    def __init__(self):
        self.sheets_client = None
        self._setup_sheets_client()
    
    def _setup_sheets_client(self):
        """Google Sheetsクライアントの設定"""
        try:
            creds = Credentials.from_service_account_file(
                config.GOOGLE_SHEETS_CREDENTIALS_PATH,
                scopes=config.GOOGLE_SHEETS_SCOPES
            )
            self.sheets_client = gspread.authorize(creds)
            print("Google Sheets接続成功")
        except Exception as e:
            print(f"Google Sheets接続エラー: {e}")
            self.sheets_client = None
    
    def get_portfolio_from_sheets(self) -> List[Dict]:
        """
        スプレッドシートから保有株式リストを取得
        Returns:
            List[Dict]: 株式情報のリスト
        """
        if not self.sheets_client:
            print("Google Sheetsクライアントが初期化されていません")
            return []
        
        try:
            sheet = self.sheets_client.open_by_key(config.SPREADSHEET_ID)
            worksheet = sheet.worksheet(config.WORKSHEET_NAME)
            
            # データを取得
            data = worksheet.get_all_records()
            portfolio = []
            
            for row in data:
                if config.STOCK_SYMBOL_COLUMN in row:
                    stock_info = {
                        'symbol': row[config.STOCK_SYMBOL_COLUMN],
                        'quantity': row.get(config.QUANTITY_COLUMN, 0)
                    }
                    portfolio.append(stock_info)
            
            print(f"ポートフォリオ取得完了: {len(portfolio)}銘柄")
            return portfolio
            
        except Exception as e:
            print(f"スプレッドシート読み込みエラー: {e}")
            return []
    
    def get_stock_prices(self, symbols: List[str]) -> Dict[str, Dict]:
        """
        株価情報を取得
        Args:
            symbols: 株式銘柄のリスト
        Returns:
            Dict: 銘柄ごとの株価情報
        """
        stock_data = {}
        
        for symbol in symbols:
            try:
                stock = yf.Ticker(symbol)
                info = stock.info
                hist = stock.history(period="5d")
                
                if not hist.empty:
                    current_price = hist['Close'].iloc[-1]
                    previous_price = hist['Close'].iloc[-2] if len(hist) > 1 else current_price
                    change = current_price - previous_price
                    change_percent = (change / previous_price) * 100 if previous_price != 0 else 0
                    
                    stock_data[symbol] = {
                        'current_price': current_price,
                        'previous_price': previous_price,
                        'change': change,
                        'change_percent': change_percent,
                        'company_name': info.get('longName', symbol),
                        'currency': info.get('currency', 'USD')
                    }
                    
                    print(f"{symbol}: ${current_price:.2f} ({change_percent:+.2f}%)")
                else:
                    print(f"{symbol}: 価格データが取得できませんでした")
                    
            except Exception as e:
                print(f"{symbol}の株価取得エラー: {e}")
                continue
        
        return stock_data
    
    def get_portfolio_with_prices(self) -> Dict:
        """
        ポートフォリオと株価情報を統合して取得
        Returns:
            Dict: ポートフォリオと株価情報
        """
        portfolio = self.get_portfolio_from_sheets()
        if not portfolio:
            return {}
        
        symbols = [stock['symbol'] for stock in portfolio]
        stock_prices = self.get_stock_prices(symbols)
        
        # ポートフォリオ情報と株価情報を統合
        portfolio_with_prices = {
            'portfolio': portfolio,
            'stock_prices': stock_prices,
            'total_value': 0
        }
        
        # 総資産価値を計算
        total_value = 0
        for stock in portfolio:
            symbol = stock['symbol']
            quantity = stock['quantity']
            if symbol in stock_prices:
                current_price = stock_prices[symbol]['current_price']
                total_value += current_price * quantity
        
        portfolio_with_prices['total_value'] = total_value
        
        return portfolio_with_prices