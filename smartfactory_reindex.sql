-- SmartFactory index trade-off lab
-- MySQL 8.x / InnoDB

CREATE DATABASE IF NOT EXISTS smartfactory_db;
USE smartfactory_db;

DROP TABLE IF EXISTS SensorLogs;

CREATE TABLE SensorLogs (
    log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    sensor_id INT NOT NULL,
    recorded_at DATETIME NOT NULL,
    temperature DECIMAL(5, 2),
    humidity DECIMAL(5, 2),
    status VARCHAR(20)
) ENGINE = InnoDB;

-- Sample telemetry rows for a reproducible local EXPLAIN run.
INSERT INTO SensorLogs
    (sensor_id, recorded_at, temperature, humidity, status)
SELECT
    100 + MOD(seq, 20),
    '2026-06-20 00:00:00' + INTERVAL seq MINUTE,
    18.00 + MOD(seq, 1500) / 100,
    35.00 + MOD(seq, 5000) / 100,
    CASE
        WHEN MOD(seq, 100) = 0 THEN 'CRITICAL'
        WHEN MOD(seq, 10) = 0 THEN 'WARNING'
        ELSE 'NORMAL'
    END
FROM (
    SELECT a.n + b.n * 10 + c.n * 100 + d.n * 1000 + 1 AS seq
    FROM (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a,
         (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b,
         (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c,
         (SELECT 0 n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d
) numbers;

-- Dashboard query. The fat index covers all selected columns.
SET @dashboard_sql = "SELECT temperature, humidity, status FROM SensorLogs WHERE sensor_id = 105 AND recorded_at >= '2026-06-20'";

CREATE INDEX idx_fat_covering
ON SensorLogs(sensor_id, recorded_at, temperature, humidity, status);

-- Baseline: EXPLAIN should be able to use the fat covering index.
EXPLAIN SELECT temperature, humidity, status
FROM SensorLogs
WHERE sensor_id = 105 AND recorded_at >= '2026-06-20';

SHOW TABLE STATUS LIKE 'SensorLogs';
SELECT table_name,
       ROUND(data_length / 1024 / 1024, 2) AS data_mb,
       ROUND(index_length / 1024 / 1024, 2) AS index_mb,
       ROUND((data_length + index_length) / 1024 / 1024, 2) AS total_mb
FROM information_schema.TABLES
WHERE table_schema = 'smartfactory_db' AND table_name = 'SensorLogs';

-- Optimization: keep only columns needed for filtering/range lookup.
ALTER TABLE SensorLogs DROP INDEX idx_fat_covering;
CREATE INDEX idx_lean_search ON SensorLogs(sensor_id, recorded_at);

-- Optimized plan: key should be idx_lean_search and Extra should not say Using index.
EXPLAIN SELECT temperature, humidity, status
FROM SensorLogs
WHERE sensor_id = 105 AND recorded_at >= '2026-06-20';

SHOW TABLE STATUS LIKE 'SensorLogs';
SELECT table_name,
       ROUND(data_length / 1024 / 1024, 2) AS data_mb,
       ROUND(index_length / 1024 / 1024, 2) AS index_mb,
       ROUND((data_length + index_length) / 1024 / 1024, 2) AS total_mb
FROM information_schema.TABLES
WHERE table_schema = 'smartfactory_db' AND table_name = 'SensorLogs';

SHOW INDEX FROM SensorLogs;
