#!/bin/bash
# yfinanceなしで代替金融APIを使用するLayer作成スクリプト

echo "📦 軽量な金融データLayer作成中..."

# 5番目のLayerとして軽量な金融データ取得ライブラリを作成
mkdir -p layer_finance_alt/python
cd layer_finance_alt

# 軽量なライブラリのみインストール（yfinanceは除外）
pip install requests -t python/

if [ $? -eq 0 ]; then
    echo "✅ 代替金融データLayer依存関係インストール完了"
    echo "📦 Layer zip作成中..."
    zip -r9 ../lambda_layer_finance_alternative.zip python/
    cd ..
    echo "✅ 代替金融データLayer作成完了: $(du -h lambda_layer_finance_alternative.zip | cut -f1)"
    
    # サイズ確認
    size=$(du -m lambda_layer_finance_alternative.zip | cut -f1)
    if [ $size -lt 50 ]; then
        echo "✅ サイズ制限内 (${size}MB / 50MB)"
    else
        echo "❌ サイズ制限超過 (${size}MB / 50MB)"
    fi
else
    echo "❌ 代替金融データLayer インストールエラー"
    exit 1
fi

# クリーンアップ
rm -rf layer_finance_alt

echo ""
echo "📋 使用可能な5つのLayers:"
echo "  1. lambda_layer1a_pandas.zip (42MB) - pandas, numpy"
echo "  2. lambda_layer1b2_scraping.zip (1MB) - beautifulsoup4, tqdm, frozendict"
echo "  3. lambda_layer1c_web.zip (11MB) - websockets, curl_cffi, protobuf"
echo "  4. lambda_layer2_google.zip (30MB) - google-generativeai"
echo "  5. lambda_layer_finance_alternative.zip (~1MB) - requests (yfinance代替)"
echo ""
echo "💡 yfinanceの代わりに以下のAPIを使用することを推奨:"
echo "   - Alpha Vantage API"
echo "   - Financial Modeling Prep API"
echo "   - IEX Cloud API"
echo "   - Yahoo Finance REST API (直接HTTP requests)"
