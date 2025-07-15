"""
Lambda用設定ファイル
環境変数から直接読み込み（dotenvは使用しない）
"""
import os

# Google Sheets設定
GOOGLE_SHEETS_CREDENTIALS_PATH = os.environ.get('GOOGLE_SHEETS_CREDENTIALS_PATH', '/tmp/credentials.json')
SPREADSHEET_ID = os.environ.get('SPREADSHEET_ID')
GOOGLE_SHEETS_SCOPES = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive'
]

# Gemini API設定
GOOGLE_API_KEY = os.environ.get('GOOGLE_API_KEY')

# Slack API設定
SLACK_BOT_TOKEN = os.environ.get('SLACK_BOT_TOKEN')
SLACK_SIGNING_SECRET = os.environ.get('SLACK_SIGNING_SECRET')
SLACK_CHANNEL = os.environ.get('SLACK_CHANNEL', 'C095G945ZNE')  # チャンネルID直接指定

# その他の設定
WORKSHEET_NAME = 'Sheet1'  # デフォルトのワークシート名（変更可能）
STOCK_SYMBOL_COLUMN = '証券コード'  # 株式銘柄のカラム名
QUANTITY_COLUMN = '保有株数'  # 保有数量のカラム名

# AWS S3設定（Google認証情報用）
CREDENTIALS_S3_BUCKET = os.environ.get('CREDENTIALS_S3_BUCKET')
CREDENTIALS_S3_KEY = os.environ.get('CREDENTIALS_S3_KEY', 'credentials/google-sheets-credentials.json')
