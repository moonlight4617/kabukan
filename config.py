import os
from dotenv import load_dotenv

load_dotenv()

# Google Sheets設定
GOOGLE_SHEETS_CREDENTIALS_PATH = os.getenv('GOOGLE_SHEETS_CREDENTIALS_PATH')
SPREADSHEET_ID = os.getenv('SPREADSHEET_ID')
GOOGLE_SHEETS_SCOPES = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive'
]

# Gemini API設定
GOOGLE_API_KEY = os.getenv('GOOGLE_API_KEY')

# その他の設定
WORKSHEET_NAME = 'Sheet1'  # デフォルトのワークシート名
STOCK_SYMBOL_COLUMN = '証券コード'  # 株式銘柄のカラム名
QUANTITY_COLUMN = '保有株数'  # 保有数量のカラム名