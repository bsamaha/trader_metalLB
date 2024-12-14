-- Connect to TimescaleDB and create schema
CREATE DATABASE trading;
\c trading

-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Create OHLCV table with TimescaleDB
CREATE TABLE candles (
    time        TIMESTAMPTZ NOT NULL,
    symbol      TEXT NOT NULL,
    open        NUMERIC(20,8) NOT NULL,
    high        NUMERIC(20,8) NOT NULL,
    low         NUMERIC(20,8) NOT NULL,
    close       NUMERIC(20,8) NOT NULL,
    volume      NUMERIC(20,8) NOT NULL,
    interval    INTERVAL NOT NULL,
    CONSTRAINT candles_time_symbol_unique UNIQUE (time, symbol)
);

-- Create hypertable with better chunking interval (1 day chunks for 5min candles)
SELECT create_hypertable('candles', 'time', chunk_time_interval => INTERVAL '1 day');

-- Optimize indexes
DROP INDEX IF EXISTS idx_candles_symbol;
CREATE INDEX idx_candles_symbol_time ON candles (symbol, time DESC) INCLUDE (close);

-- Add compression policy
ALTER TABLE candles SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'symbol',
    timescaledb.compress_orderby = 'time DESC'
);

-- Automatically compress chunks older than 1 day
SELECT add_compression_policy('candles', INTERVAL '1 day');

-- Create trades table
CREATE TABLE trades (
    id          SERIAL,
    time        TIMESTAMPTZ NOT NULL,
    symbol      TEXT NOT NULL,
    side        TEXT NOT NULL,
    price       NUMERIC NOT NULL,
    size        NUMERIC NOT NULL,
    fee         NUMERIC NOT NULL,
    order_id    TEXT NOT NULL,
    PRIMARY KEY (id, time)
);

-- Create hypertable for trades
SELECT create_hypertable('trades', 'time');

-- Create service user with limited privileges
CREATE USER trading_service WITH PASSWORD :'SERVICE_PASSWORD';

-- Grant database-level permissions
GRANT CONNECT ON DATABASE trading TO trading_service;

-- Grant schema-level permissions
GRANT USAGE ON SCHEMA public TO trading_service;

-- Grant table-level permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO trading_service;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO trading_service;

-- Grant permissions for TimescaleDB-specific functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO trading_service;

-- Grant permissions for future tables and sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO trading_service;
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT USAGE, SELECT ON SEQUENCES TO trading_service;

-- Grant permissions to use TimescaleDB features
GRANT SELECT ON ALL TABLES IN SCHEMA _timescaledb_internal TO trading_service;
GRANT SELECT ON ALL TABLES IN SCHEMA _timescaledb_catalog TO trading_service;
GRANT SELECT ON ALL TABLES IN SCHEMA _timescaledb_config TO trading_service;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA _timescaledb_internal TO trading_service;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA _timescaledb_functions TO trading_service;