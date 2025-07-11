#!/usr/bin/env python3
"""
ポートフォリオ分析のテストファイル
"""

import unittest
from unittest.mock import Mock, patch
import sys
import os

# プロジェクトルートをパスに追加
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from data_fetcher import DataFetcher
from analyzer import PortfolioAnalyzer
from mcp_client import MCPClient

class TestDataFetcher(unittest.TestCase):
    def setUp(self):
        self.data_fetcher = DataFetcher()
    
    def test_portfolio_structure(self):
        """ポートフォリオデータの構造をテスト"""
        # モックデータ
        mock_portfolio = [
            {'symbol': 'AAPL', 'quantity': 10},
            {'symbol': 'GOOGL', 'quantity': 5}
        ]
        
        # データフェッチャーのメソッドをモック
        with patch.object(self.data_fetcher, 'get_portfolio_from_sheets', return_value=mock_portfolio):
            with patch.object(self.data_fetcher, 'get_stock_prices', return_value={
                'AAPL': {
                    'current_price': 150.00,
                    'previous_price': 148.00,
                    'change': 2.00,
                    'change_percent': 1.35,
                    'company_name': 'Apple Inc.',
                    'currency': 'USD'
                },
                'GOOGL': {
                    'current_price': 2800.00,
                    'previous_price': 2750.00,
                    'change': 50.00,
                    'change_percent': 1.82,
                    'company_name': 'Alphabet Inc.',
                    'currency': 'USD'
                }
            }):
                result = self.data_fetcher.get_portfolio_with_prices()
                
                # 基本構造のチェック
                self.assertIn('portfolio', result)
                self.assertIn('stock_prices', result)
                self.assertIn('total_value', result)
                
                # 計算値のチェック
                expected_total = (150.00 * 10) + (2800.00 * 5)
                self.assertEqual(result['total_value'], expected_total)

class TestPortfolioAnalyzer(unittest.TestCase):
    def setUp(self):
        self.analyzer = PortfolioAnalyzer()
        self.sample_data = {
            'portfolio': [
                {'symbol': 'AAPL', 'quantity': 10},
                {'symbol': 'GOOGL', 'quantity': 5}
            ],
            'stock_prices': {
                'AAPL': {
                    'current_price': 150.00,
                    'previous_price': 148.00,
                    'change': 2.00,
                    'change_percent': 1.35,
                    'company_name': 'Apple Inc.',
                    'currency': 'USD'
                },
                'GOOGL': {
                    'current_price': 2800.00,
                    'previous_price': 2750.00,
                    'change': 50.00,
                    'change_percent': 1.82,
                    'company_name': 'Alphabet Inc.',
                    'currency': 'USD'
                }
            },
            'total_value': 15500.00
        }
    
    def test_analyze_portfolio(self):
        """ポートフォリオ分析のテスト"""
        result = self.analyzer.analyze_portfolio(self.sample_data)
        
        # 分析結果の基本構造
        self.assertIn('total_portfolio_value', result)
        self.assertIn('number_of_holdings', result)
        self.assertIn('holdings_analysis', result)
        self.assertIn('portfolio_distribution', result)
        self.assertIn('performance_summary', result)
        self.assertIn('risk_assessment', result)
        
        # 計算値の確認
        self.assertEqual(result['total_portfolio_value'], 15500.00)
        self.assertEqual(result['number_of_holdings'], 2)
        self.assertEqual(len(result['holdings_analysis']), 2)
    
    def test_generate_report(self):
        """レポート生成のテスト"""
        analysis = self.analyzer.analyze_portfolio(self.sample_data)
        report = self.analyzer.generate_report(analysis)
        
        # レポートの基本的な内容を確認
        self.assertIn('ポートフォリオ分析レポート', report)
        self.assertIn('総資産価値', report)
        self.assertIn('保有銘柄数', report)
        self.assertIn('Apple Inc.', report)
        self.assertIn('Alphabet Inc.', report)

class TestMCPClient(unittest.TestCase):
    def setUp(self):
        self.mcp_client = MCPClient()
    
    def test_format_portfolio_for_analysis(self):
        """ポートフォリオフォーマットのテスト"""
        sample_data = {
            'portfolio': [
                {'symbol': 'AAPL', 'quantity': 10}
            ],
            'stock_prices': {
                'AAPL': {
                    'current_price': 150.00,
                    'change_percent': 1.35,
                    'company_name': 'Apple Inc.'
                }
            },
            'total_value': 1500.00
        }
        
        result = self.mcp_client._format_portfolio_for_analysis(sample_data)
        
        # フォーマット結果の確認
        self.assertIn('総資産価値', result)
        self.assertIn('Apple Inc.', result)
        self.assertIn('AAPL', result)
        self.assertIn('$150.00', result)

def run_basic_tests():
    """基本的なテストの実行"""
    print("=== 基本テストを実行中 ===")
    
    # モックデータでのテスト
    print("\n1. データフェッチャーのテスト...")
    try:
        data_fetcher = DataFetcher()
        print("✓ DataFetcherクラスのインスタンス化成功")
    except Exception as e:
        print(f"✗ DataFetcherクラスのテスト失敗: {e}")
    
    print("\n2. アナライザーのテスト...")
    try:
        analyzer = PortfolioAnalyzer()
        print("✓ PortfolioAnalyzerクラスのインスタンス化成功")
    except Exception as e:
        print(f"✗ PortfolioAnalyzerクラスのテスト失敗: {e}")
    
    print("\n3. MCPクライアントのテスト...")
    try:
        mcp_client = MCPClient()
        print("✓ MCPClientクラスのインスタンス化成功")
    except Exception as e:
        print(f"✗ MCPClientクラスのテスト失敗: {e}")
    
    print("\n=== 基本テスト完了 ===")

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='ポートフォリオアプリケーションのテスト')
    parser.add_argument('--basic', action='store_true', help='基本的なテストのみ実行')
    parser.add_argument('--unittest', action='store_true', help='unittestを実行')
    
    args = parser.parse_args()
    
    if args.basic:
        run_basic_tests()
    elif args.unittest:
        unittest.main(argv=[''], exit=False)
    else:
        print("使用方法:")
        print("  python tests/test_portfolio.py --basic     # 基本テスト")
        print("  python tests/test_portfolio.py --unittest  # unittest実行")