import pandas as pd
from typing import Dict, List, Optional
from datetime import datetime

class PortfolioAnalyzer:
    def __init__(self):
        pass
    
    def analyze_portfolio(self, portfolio_data: Dict) -> Dict:
        """
        ポートフォリオの基本分析を実行
        Args:
            portfolio_data: ポートフォリオデータ
        Returns:
            Dict: 分析結果
        """
        if not portfolio_data:
            return {}
        
        portfolio = portfolio_data.get('portfolio', [])
        stock_prices = portfolio_data.get('stock_prices', {})
        total_value = portfolio_data.get('total_value', 0)
        
        analysis = {
            'total_portfolio_value': total_value,
            'number_of_holdings': len(portfolio),
            'holdings_analysis': [],
            'portfolio_distribution': {},
            'performance_summary': {},
            'risk_assessment': {}
        }
        
        # 各銘柄の詳細分析
        for stock in portfolio:
            symbol = stock['symbol']
            quantity = stock['quantity']
            
            if symbol in stock_prices:
                price_info = stock_prices[symbol]
                current_price = price_info['current_price']
                change_percent = price_info['change_percent']
                company_name = price_info['company_name']
                
                holding_value = current_price * quantity
                portfolio_weight = (holding_value / total_value) * 100 if total_value > 0 else 0
                
                holding_analysis = {
                    'symbol': symbol,
                    'company_name': company_name,
                    'quantity': quantity,
                    'current_price': current_price,
                    'holding_value': holding_value,
                    'portfolio_weight': portfolio_weight,
                    'daily_change_percent': change_percent,
                    'daily_pnl': holding_value * (change_percent / 100)
                }
                
                analysis['holdings_analysis'].append(holding_analysis)
        
        # ポートフォリオ分散の計算
        analysis['portfolio_distribution'] = self._calculate_portfolio_distribution(
            analysis['holdings_analysis']
        )
        
        # パフォーマンス要約
        analysis['performance_summary'] = self._calculate_performance_summary(
            analysis['holdings_analysis']
        )
        
        # リスク評価
        analysis['risk_assessment'] = self._assess_risk(
            analysis['holdings_analysis']
        )
        
        return analysis
    
    def _calculate_portfolio_distribution(self, holdings: List[Dict]) -> Dict:
        """
        ポートフォリオの分散状況を計算
        Args:
            holdings: 保有銘柄のリスト
        Returns:
            Dict: 分散分析結果
        """
        if not holdings:
            return {}
        
        # 銘柄別の重み
        weights = [holding['portfolio_weight'] for holding in holdings]
        
        # 上位保有銘柄
        sorted_holdings = sorted(holdings, key=lambda x: x['portfolio_weight'], reverse=True)
        top_holdings = sorted_holdings[:5]
        
        # 集中度の計算（上位5銘柄の重み）
        concentration = sum([holding['portfolio_weight'] for holding in top_holdings])
        
        return {
            'top_holdings': top_holdings,
            'concentration_top5': concentration,
            'is_diversified': concentration < 60,  # 上位5銘柄が60%未満なら分散されている
            'average_weight': sum(weights) / len(weights) if weights else 0
        }
    
    def _calculate_performance_summary(self, holdings: List[Dict]) -> Dict:
        """
        パフォーマンス要約を計算
        Args:
            holdings: 保有銘柄のリスト
        Returns:
            Dict: パフォーマンス要約
        """
        if not holdings:
            return {}
        
        # 日次損益の計算
        daily_pnl = sum([holding['daily_pnl'] for holding in holdings])
        total_value = sum([holding['holding_value'] for holding in holdings])
        
        # 加重平均リターン
        weighted_return = 0
        for holding in holdings:
            weight = holding['portfolio_weight'] / 100
            weighted_return += weight * holding['daily_change_percent']
        
        # 勝ち銘柄と負け銘柄の数
        winners = len([h for h in holdings if h['daily_change_percent'] > 0])
        losers = len([h for h in holdings if h['daily_change_percent'] < 0])
        
        return {
            'daily_pnl': daily_pnl,
            'daily_return_percent': (daily_pnl / total_value) * 100 if total_value > 0 else 0,
            'weighted_return': weighted_return,
            'winners': winners,
            'losers': losers,
            'win_rate': (winners / len(holdings)) * 100 if holdings else 0
        }
    
    def _assess_risk(self, holdings: List[Dict]) -> Dict:
        """
        リスク評価を実行
        Args:
            holdings: 保有銘柄のリスト
        Returns:
            Dict: リスク評価結果
        """
        if not holdings:
            return {}
        
        # 日次変動率の分析
        daily_changes = [holding['daily_change_percent'] for holding in holdings]
        
        # 標準偏差（ボラティリティの代理指標）
        import statistics
        volatility = statistics.stdev(daily_changes) if len(daily_changes) > 1 else 0
        
        # 最大の負の変動
        max_loss = min(daily_changes) if daily_changes else 0
        
        # 大きな変動の銘柄数
        high_volatility_count = len([change for change in daily_changes if abs(change) > 5])
        
        # リスクレベルの判定
        risk_level = "低"
        if volatility > 3:
            risk_level = "高"
        elif volatility > 1.5:
            risk_level = "中"
        
        return {
            'portfolio_volatility': volatility,
            'max_daily_loss': max_loss,
            'high_volatility_holdings': high_volatility_count,
            'risk_level': risk_level,
            'risk_score': min(10, max(1, int(volatility * 2)))  # 1-10のスコア
        }
    
    def generate_report(self, analysis: Dict) -> str:
        """
        分析結果のレポートを生成
        Args:
            analysis: 分析結果
        Returns:
            str: 分析レポート
        """
        if not analysis:
            return "分析データがありません"
        
        report = f"""
=== ポートフォリオ分析レポート ===
生成日時: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

【概要】
総資産価値: ${analysis['total_portfolio_value']:,.2f}
保有銘柄数: {analysis['number_of_holdings']}銘柄

【パフォーマンス】
日次損益: ${analysis['performance_summary'].get('daily_pnl', 0):,.2f}
日次リターン: {analysis['performance_summary'].get('daily_return_percent', 0):+.2f}%
勝ち銘柄: {analysis['performance_summary'].get('winners', 0)}銘柄
負け銘柄: {analysis['performance_summary'].get('losers', 0)}銘柄
勝率: {analysis['performance_summary'].get('win_rate', 0):.1f}%

【リスク評価】
リスクレベル: {analysis['risk_assessment'].get('risk_level', '不明')}
ポートフォリオ変動性: {analysis['risk_assessment'].get('portfolio_volatility', 0):.2f}%
最大日次損失: {analysis['risk_assessment'].get('max_daily_loss', 0):+.2f}%

【分散状況】
上位5銘柄集中度: {analysis['portfolio_distribution'].get('concentration_top5', 0):.1f}%
分散状況: {'良好' if analysis['portfolio_distribution'].get('is_diversified', False) else '要改善'}

【上位保有銘柄】
"""
        
        top_holdings = analysis['portfolio_distribution'].get('top_holdings', [])
        for i, holding in enumerate(top_holdings, 1):
            report += f"{i}. {holding['company_name']} ({holding['symbol']}): {holding['portfolio_weight']:.1f}%\n"
        
        return report