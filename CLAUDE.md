# CLAUDE.md
ユーザーには日本語で応答してください。
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Python-based data analysis project that appears to be in early development stages. The project includes:

- Financial data fetching capabilities (yfinance)
- Google Sheets integration (gspread)
- MCP (Model Context Protocol) client integration
- Data analysis tools using pandas

## Architecture

The project follows a modular structure with separate components:

- `main.py` - Entry point (currently empty)
- `config.py` - Configuration management (currently empty)
- `analyzer.py` - Data analysis functionality (currently empty)
- `data-fetcher.py` - Data fetching operations (currently empty)
- `mcp_client.py` - MCP client integration (currently empty)
- `mcp.json` - MCP server configuration for Gemini API integration

## Development Commands

### Environment Setup
```bash
# Install dependencies
pip install -r requirements.txt

# Set up environment variables
cp .env.example .env
# Edit .env file with your actual credentials
```

### Running the Application
```bash
# Main application
python main.py

# Show help
python main.py --help

# Run tests
python tests/test_portfolio.py --basic
python tests/test_portfolio.py --unittest
```

## Key Dependencies

- `python-dotenv==1.0.0` - Environment variable management
- `requests==2.31.0` - HTTP requests
- `pandas==2.1.0` - Data manipulation and analysis
- `gspread==5.10.0` - Google Sheets API integration
- `google-auth==2.22.0` - Google authentication
- `yfinance==0.2.20` - Yahoo Finance data retrieval

## MCP Integration

The project includes MCP (Model Context Protocol) configuration for Gemini API integration. The `mcp.json` file configures a Gemini server that requires a `GOOGLE_API_KEY` environment variable.

## Application Features

The application provides complete stock portfolio analysis and investment advice:

### Core Functionality
1. **Google Sheets Integration**: Reads portfolio data from Google Sheets
2. **Stock Price Fetching**: Uses yfinance to get current stock prices
3. **Portfolio Analysis**: Calculates performance metrics, risk assessment, and diversification
4. **AI Investment Advice**: Uses Gemini API via MCP for investment recommendations

### Setup Requirements
1. **Google Sheets**: Create a spreadsheet with columns 'symbol' and 'quantity'
2. **Service Account**: Set up Google Sheets API credentials
3. **Gemini API**: Obtain API key for investment advice
4. **Environment Variables**: Configure .env file with credentials

### Expected Spreadsheet Format
```
symbol  | quantity
--------|----------
AAPL    | 10
GOOGL   | 5
MSFT    | 8
```
