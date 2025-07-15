import gspread
import requests
from google.oauth2.service_account import Credentials
from typing import List, Dict, Optional
import config
import json
from datetime import datetime, timedelta

class DataFetcher:
    def __init__(self):
        self.sheets_client = None
        self._setup_sheets_client()
    
    def _setup_sheets_client(self):
        """Google Sheetsクライアントの設定"""
        try:
            if not config.GOOGLE_SHEETS_CREDENTIALS_PATH:
                print("Google Sheets認証情報のパスが設定されていません")
                self.sheets_client = None
                return
                
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
            
            # 利用可能なワークシート名を確認
            worksheets = sheet.worksheets()
            worksheet_names = [ws.title for ws in worksheets]
            print(f"利用可能なワークシート: {worksheet_names}")
            
            # 最初のワークシートを使用
            if worksheets:
                worksheet = worksheets[0]
                print(f"使用するワークシート: {worksheet.title}")
            else:
                print("ワークシートが見つかりません")
                return []
            
            # データを取得
            data = worksheet.get_all_records()
            
            # デバッグ: スプレッドシートの内容を確認
            print(f"スプレッドシートのデータ数: {len(data)}")
            if data:
                print(f"最初の行のカラム: {list(data[0].keys())}")
                print(f"最初の行の内容: {data[0]}")
            
            portfolio = []
            
            for row in data:
                if config.STOCK_SYMBOL_COLUMN in row:
                    # 日本株の場合、証券コードを文字列に変換し、.Tを付加
                    symbol_raw = row[config.STOCK_SYMBOL_COLUMN]
                    if isinstance(symbol_raw, (int, float)):
                        symbol = f"{int(symbol_raw)}.T"  # 日本株の場合
                    else:
                        symbol = str(symbol_raw)
                    
                    stock_info = {
                        'symbol': symbol,
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
        株価情報をYahoo Finance APIから直接取得
        Args:
            symbols: 株式銘柄のリスト
        Returns:
            Dict: 銘柄ごとの株価情報
        """
        stock_data = {}
        
        for symbol in symbols:
            try:
                # Yahoo Finance APIから株価データを取得
                price_data = self._fetch_stock_price_from_yahoo_api(symbol)
                if price_data:
                    stock_data[symbol] = price_data
                    currency = price_data.get('currency', 'USD')
                    if currency == 'JPY':
                        print(f"{symbol}: ¥{price_data['current_price']:,.0f} ({price_data['change_percent']:+.2f}%)")
                    else:
                        print(f"{symbol}: ${price_data['current_price']:.2f} ({price_data['change_percent']:+.2f}%)")
                else:
                    print(f"{symbol}: 価格データが取得できませんでした")
                    
            except Exception as e:
                print(f"{symbol}の株価取得エラー: {e}")
                continue
        
        return stock_data
    
    def _fetch_stock_price_from_yahoo_api(self, symbol: str) -> Optional[Dict]:
        """
        Yahoo Finance APIから単一銘柄の株価を取得
        Args:
            symbol: 株式銘柄コード
        Returns:
            Dict: 株価情報
        """
        try:
            # Yahoo Finance Chart APIを使用
            url = f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol}"
            
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            
            # 5日間のデータを取得
            params = {
                'range': '5d',
                'interval': '1d'
            }
            
            response = requests.get(url, headers=headers, params=params, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            
            if data['chart']['error'] is not None:
                print(f"Yahoo API エラー: {data['chart']['error']}")
                return None
                
            result = data['chart']['result'][0]
            
            if not result['timestamp'] or not result['indicators']['quote'][0]['close']:
                return None
            
            # 終値データを取得
            close_prices = result['indicators']['quote'][0]['close']
            # NoneやNaN値を除去
            close_prices = [price for price in close_prices if price is not None]
            
            if len(close_prices) < 1:
                return None
            
            current_price = close_prices[-1]
            previous_price = close_prices[-2] if len(close_prices) > 1 else current_price
            
            change = current_price - previous_price
            change_percent = (change / previous_price) * 100 if previous_price != 0 else 0
            
            # 会社名を取得
            company_name = symbol
            currency = 'USD'
            
            # メタデータから会社名と通貨を取得
            meta = result.get('meta', {})
            if 'longName' in meta:
                company_name = meta['longName']
            elif 'shortName' in meta:
                company_name = meta['shortName']
            
            if 'currency' in meta:
                currency = meta['currency']
            
            return {
                'current_price': current_price,
                'previous_price': previous_price,
                'change': change,
                'change_percent': change_percent,
                'company_name': company_name,
                'currency': currency
            }
            
        except requests.exceptions.RequestException as e:
            print(f"Yahoo Finance API リクエストエラー ({symbol}): {e}")
            return None
        except (KeyError, IndexError, TypeError) as e:
            print(f"Yahoo Finance API レスポンス解析エラー ({symbol}): {e}")
            return None
        except Exception as e:
            print(f"予期しないエラー ({symbol}): {e}")
            return None
    
    def get_usd_jpy_rate(self) -> float:
        """
        USD/JPY為替レートを取得
        Returns:
            float: USD/JPY為替レート
        """
        try:
            url = "https://query1.finance.yahoo.com/v8/finance/chart/USDJPY=X"
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            
            response = requests.get(url, headers=headers, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            
            if data['chart']['error'] is not None:
                print(f"為替レート取得エラー: {data['chart']['error']}")
                return 150.0  # デフォルト値
            
            result = data['chart']['result'][0]
            close_prices = result['indicators']['quote'][0]['close']
            close_prices = [price for price in close_prices if price is not None]
            
            if close_prices:
                usd_jpy_rate = close_prices[-1]
                print(f"USD/JPY為替レート: {usd_jpy_rate:.2f}")
                return usd_jpy_rate
            else:
                print("為替レートデータが取得できませんでした")
                return 150.0
                
        except Exception as e:
            print(f"為替レート取得エラー: {e}")
            return 150.0  # デフォルト値

    def get_portfolio_with_prices(self) -> Dict:
        """
        ポートフォリオと株価情報を統合して取得（円換算機能付き）
        Returns:
            Dict: ポートフォリオと株価情報
        """
        portfolio = self.get_portfolio_from_sheets()
        if not portfolio:
            return {}
        
        symbols = [stock['symbol'] for stock in portfolio]
        stock_prices = self.get_stock_prices(symbols)
        
        # USD/JPY為替レートを取得
        usd_jpy_rate = self.get_usd_jpy_rate()
        
        # ポートフォリオ情報と株価情報を統合
        portfolio_with_prices = {
            'portfolio': portfolio,
            'stock_prices': stock_prices,
            'usd_jpy_rate': usd_jpy_rate,
            'total_value_usd': 0,
            'total_value_jpy': 0
        }
        
        # 総資産価値を計算（USD建てとJPY建てを分けて計算）
        total_value_usd = 0
        total_value_jpy = 0
        
        for stock in portfolio:
            symbol = stock['symbol']
            quantity = stock['quantity']
            if symbol in stock_prices:
                price_info = stock_prices[symbol]
                current_price = price_info['current_price']
                currency = price_info.get('currency', 'USD')
                
                holding_value = current_price * quantity
                
                if currency == 'JPY':
                    total_value_jpy += holding_value
                else:  # USD or other currencies treated as USD
                    total_value_usd += holding_value
        
        # 米国株を円換算して合計
        total_value_jpy_converted = total_value_jpy + (total_value_usd * usd_jpy_rate)
        
        portfolio_with_prices['total_value_usd'] = total_value_usd
        portfolio_with_prices['total_value_jpy'] = total_value_jpy
        portfolio_with_prices['total_value_jpy_converted'] = total_value_jpy_converted
        
        return portfolio_with_prices