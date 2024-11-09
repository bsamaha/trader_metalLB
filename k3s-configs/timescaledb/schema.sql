-- Connect to TimescaleDB and create schema
CREATE DATABASE trading;
\c trading

-- Create OHLCV table with TimescaleDB
CREATE TABLE candles (
    time        TIMESTAMPTZ NOT NULL,
    symbol      TEXT NOT NULL,
    open        NUMERIC NOT NULL,
    high        NUMERIC NOT NULL,
    low         NUMERIC NOT NULL,
    close       NUMERIC NOT NULL,
    volume      NUMERIC NOT NULL,
    interval    INTERVAL NOT NULL
);

-- Create hypertable
SELECT create_hypertable('candles', 'time');

-- Create indexes
CREATE INDEX idx_candles_symbol ON candles (symbol, time DESC);

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