import os
import gspread
from google.oauth2.service_account import Credentials
from dotenv import load_dotenv

load_dotenv()

# 認証情報の設定
SCOPES = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive'
]

def test_google_sheets():
    try:
        # サービスアカウントで認証
        creds = Credentials.from_service_account_file(
            os.getenv('GOOGLE_SHEETS_CREDENTIALS_PATH'),
            scopes=SCOPES
        )
        
        # Google Sheetsクライアントを作成
        client = gspread.authorize(creds)
        
        # スプレッドシートを開く
        sheet = client.open_by_key(os.getenv('SPREADSHEET_ID'))
        worksheet = sheet.sheet1
        
        # データを読み取り
        data = worksheet.get_all_records()
        print("取得したデータ:")
        for row in data:
            print(row)
            
        return True
        
    except Exception as e:
        print(f"エラー: {e}")
        return False

if __name__ == "__main__":
    if test_google_sheets():
        print("Google Sheets API接続成功！")
    else:
        print("Google Sheets API接続失敗")
        