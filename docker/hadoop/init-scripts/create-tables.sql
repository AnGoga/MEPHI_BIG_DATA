-- =============================================================================
-- MOEX Data Warehouse - Hive Table Definitions
-- =============================================================================
-- This script creates the database and tables for storing MOEX trading data
-- in Apache Hive. Tables are stored in Parquet format for optimal compression
-- and query performance.
-- =============================================================================

-- Create database
CREATE DATABASE IF NOT EXISTS moex_data
COMMENT 'MOEX trading data warehouse'
LOCATION '/user/moex/warehouse';

USE moex_data;

-- =============================================================================
-- Trades Table (Partitioned by date)
-- =============================================================================
-- Stores all trading transactions from MOEX
-- Partitioned by trade_date for efficient time-based queries
-- =============================================================================

CREATE EXTERNAL TABLE IF NOT EXISTS trades (
    trade_no BIGINT COMMENT 'Unique trade number',
    trade_time STRING COMMENT 'Trade timestamp (HH:mm:ss)',
    sec_id STRING COMMENT 'Security ID (ticker symbol)',
    board_id STRING COMMENT 'Trading board ID',
    price DECIMAL(18,2) COMMENT 'Trade price',
    quantity BIGINT COMMENT 'Number of securities traded',
    value DECIMAL(18,2) COMMENT 'Trade value (price * quantity)',
    buy_sell STRING COMMENT 'Buy (B) or Sell (S)',
    period STRING COMMENT 'Trading period',
    trading_session STRING COMMENT 'Trading session identifier',
    system_time STRING COMMENT 'System timestamp'
)
PARTITIONED BY (trade_date STRING COMMENT 'Trade date (YYYY-MM-DD)')
STORED AS PARQUET
LOCATION '/user/moex/trades'
TBLPROPERTIES (
    'parquet.compression'='SNAPPY',
    'comment'='MOEX trades data partitioned by date'
);

-- =============================================================================
-- Instruments Table
-- =============================================================================
-- Stores information about trading instruments (securities)
-- No partitioning as this is a relatively small dimension table
-- =============================================================================

CREATE EXTERNAL TABLE IF NOT EXISTS instruments (
    sec_id STRING COMMENT 'Security ID (ticker symbol)',
    board_id STRING COMMENT 'Trading board ID',
    short_name STRING COMMENT 'Short name of the security',
    sec_name STRING COMMENT 'Full name of the security',
    prev_price DECIMAL(18,2) COMMENT 'Previous closing price',
    lot_size INT COMMENT 'Lot size (minimum trading unit)',
    face_value DECIMAL(18,2) COMMENT 'Face value of the security',
    status STRING COMMENT 'Trading status',
    market_price DECIMAL(18,2) COMMENT 'Current market price',
    currency_id STRING COMMENT 'Currency (RUB, USD, EUR, etc.)'
)
STORED AS PARQUET
LOCATION '/user/moex/instruments'
TBLPROPERTIES (
    'parquet.compression'='SNAPPY',
    'comment'='MOEX trading instruments reference data'
);

-- =============================================================================
-- Views for Analytics
-- =============================================================================

-- Daily trading summary by security
CREATE VIEW IF NOT EXISTS daily_trades_summary AS
SELECT
    trade_date,
    sec_id,
    COUNT(*) as trade_count,
    SUM(quantity) as total_quantity,
    SUM(value) as total_value,
    AVG(price) as avg_price,
    MIN(price) as min_price,
    MAX(price) as max_price
FROM trades
GROUP BY trade_date, sec_id;

-- Top traded securities by value
CREATE VIEW IF NOT EXISTS top_traded_securities AS
SELECT
    trade_date,
    sec_id,
    SUM(value) as total_value,
    COUNT(*) as trade_count
FROM trades
GROUP BY trade_date, sec_id
ORDER BY trade_date DESC, total_value DESC;

-- =============================================================================
-- Sample Queries (commented out, for reference)
-- =============================================================================

-- After loading data, repair partitions:
-- MSCK REPAIR TABLE trades;

-- Check partition list:
-- SHOW PARTITIONS trades;

-- Count trades by date:
-- SELECT trade_date, COUNT(*) as trade_count
-- FROM trades
-- GROUP BY trade_date
-- ORDER BY trade_date DESC;

-- Top 10 securities by trading volume for a specific date:
-- SELECT
--     sec_id,
--     COUNT(*) as trade_count,
--     SUM(value) as total_value,
--     AVG(price) as avg_price
-- FROM trades
-- WHERE trade_date = '2025-11-06'
-- GROUP BY sec_id
-- ORDER BY total_value DESC
-- LIMIT 10;

-- Join with instruments to get security names:
-- SELECT
--     t.sec_id,
--     i.short_name,
--     COUNT(*) as trade_count,
--     SUM(t.value) as total_value
-- FROM trades t
-- JOIN instruments i ON t.sec_id = i.sec_id
-- WHERE t.trade_date = '2025-11-06'
-- GROUP BY t.sec_id, i.short_name
-- ORDER BY total_value DESC
-- LIMIT 10;

-- =============================================================================
-- End of script
-- =============================================================================
