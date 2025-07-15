import json
import urllib3
import os
from datetime import datetime

def lambda_handler(event, context):
    """
    CloudWatchアラームからSNS経由で受信したアラート情報をSlackに通知する
    """
    
    # デバッグ: 受信したevent全体をログ出力
    print(f"DEBUG: Received event: {json.dumps(event, default=str)}")
    
    # Slack Webhook URL を環境変数から取得
    slack_webhook_url = os.environ.get('SLACK_WEBHOOK_URL')
    if not slack_webhook_url:
        print("ERROR: SLACK_WEBHOOK_URL environment variable not set")
        return {
            'statusCode': 400,
            'body': json.dumps('SLACK_WEBHOOK_URL not configured')
        }
    
    try:
        # デバッグ: eventの構造を確認
        print(f"DEBUG: Event keys: {list(event.keys())}")
        if 'Records' in event:
            print(f"DEBUG: Records count: {len(event['Records'])}")
            print(f"DEBUG: First record: {json.dumps(event['Records'][0], default=str)}")
        
        # SNSメッセージを解析
        print("DEBUG: Attempting to parse SNS message...")
        sns_message = json.loads(event['Records'][0]['Sns']['Message'])
        print(f"DEBUG: Parsed SNS message: {json.dumps(sns_message, default=str)}")
        
        # アラーム情報を抽出
        alarm_name = sns_message['AlarmName']
        alarm_description = sns_message['AlarmDescription']
        new_state = sns_message['NewStateValue']
        old_state = sns_message['OldStateValue']
        reason = sns_message['NewStateReason']
        timestamp = sns_message['StateChangeTime']
        region = sns_message['Region']
        
        # メトリクス情報
        metric_name = sns_message['Trigger']['MetricName']
        namespace = sns_message['Trigger']['Namespace']
        threshold = sns_message['Trigger']['Threshold']
        
        # 日本時間に変換（複数の日時形式に対応）
        try:
            # タイムゾーン情報付きの形式を試す
            if '+' in timestamp:
                utc_time = datetime.strptime(timestamp.split('+')[0], '%Y-%m-%dT%H:%M:%S.%f')
            else:
                utc_time = datetime.strptime(timestamp, '%Y-%m-%dT%H:%M:%S.%fZ')
        except ValueError:
            # 別の形式を試す
            try:
                utc_time = datetime.strptime(timestamp, '%Y-%m-%dT%H:%M:%SZ')
            except ValueError:
                utc_time = datetime.now()  # フォールバック
        
        # アラームの重要度に応じて色を設定
        if 'error' in alarm_name.lower():
            color = 'danger'  # 赤
            emoji = '🚨'
        elif 'timeout' in alarm_name.lower():
            color = 'warning'  # 黄
            emoji = '⏱️'
        elif 'throttle' in alarm_name.lower():
            color = 'warning'  # 黄
            emoji = '🛑'
        else:
            color = 'good'  # 緑
            emoji = '📊'
        
        # Slackメッセージを構築
        slack_message = {
            "username": "CloudWatch Alert",
            "icon_emoji": ":warning:",
            "attachments": [
                {
                    "color": color,
                    "title": f"{emoji} CloudWatch アラーム: {alarm_name}",
                    "text": alarm_description,
                    "fields": [
                        {
                            "title": "状態変化",
                            "value": f"{old_state} → {new_state}",
                            "short": True
                        },
                        {
                            "title": "メトリクス",
                            "value": f"{metric_name} (閾値: {threshold})",
                            "short": True
                        },
                        {
                            "title": "リージョン",
                            "value": region,
                            "short": True
                        },
                        {
                            "title": "発生時刻",
                            "value": timestamp,
                            "short": True
                        },
                        {
                            "title": "詳細",
                            "value": reason,
                            "short": False
                        }
                    ],
                    "footer": "Kabukan Lambda Monitoring",
                    "ts": int(utc_time.timestamp())
                }
            ]
        }
        
        print(f"DEBUG: Sending message to Slack: {json.dumps(slack_message)}")
        
        # Slackに送信
        http = urllib3.PoolManager()
        response = http.request(
            'POST',
            slack_webhook_url,
            body=json.dumps(slack_message),
            headers={'Content-Type': 'application/json'}
        )
        
        print(f"DEBUG: Slack response status: {response.status}")
        print(f"DEBUG: Slack response data: {response.data.decode('utf-8')}")
        
        if response.status == 200:
            print(f"Successfully sent Slack notification for alarm: {alarm_name}")
            return {
                'statusCode': 200,
                'body': json.dumps('Slack notification sent successfully')
            }
        else:
            print(f"Failed to send Slack notification. Status: {response.status}")
            return {
                'statusCode': response.status,
                'body': json.dumps(f'Failed to send Slack notification: {response.status}')
            }
            
    except Exception as e:
        print(f"ERROR: Exception in lambda_handler: {str(e)}")
        print(f"ERROR: Exception type: {type(e).__name__}")
        import traceback
        print(f"ERROR: Traceback: {traceback.format_exc()}")
        
        # エラー時もeventの内容を出力
        try:
            print(f"ERROR: Event that caused error: {json.dumps(event, default=str)}")
        except:
            print(f"ERROR: Could not serialize event: {event}")
        
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }