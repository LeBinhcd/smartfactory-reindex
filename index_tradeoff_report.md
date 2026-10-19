# SmartFactory index trade-off report

## Diagnosis

The legacy `idx_fat_covering` index contains every column required by the dashboard query: `sensor_id`, `recorded_at`, `temperature`, `humidity`, and `status`. This can produce a covering-index plan, allowing MySQL to answer the `SELECT` without looking up the clustered table record. The read benefit is real, but it is unsuitable as the default design for a high-ingest IoT table.

Every inserted sensor row must also be inserted into the secondary B-Tree. The extra decimal and string values make index records wider, so more pages are written, cached, and potentially split. This is the write penalty: faster reads are purchased with slower inserts, more RAM pressure, larger backups, and higher storage cost. Values such as temperature, humidity, and status are payload columns, not filtering columns for this dashboard query.

The replacement `idx_lean_search(sensor_id, recorded_at)` contains only the predicates used to locate the time range. After the lookup, InnoDB fetches `temperature`, `humidity`, and `status` from the clustered primary-key record. The optimized plan still uses `idx_lean_search` with `range` access, but no longer shows `Using index`; it reports `Using index condition`, because the secondary index is no longer covering.

## Measurement log

The script was executed locally on MySQL 8.0.46 with approximately 10,000 sample telemetry rows.

| Measurement | Data (MB) | Index (MB) | Total (MB) |
|---|---:|---:|---:|
| With fat covering index | 0.02 | 0.00 | 0.02 |
| With lean search index | 0.02 | 0.00 | 0.02 |

The displayed values are rounded and the test table is too small for a visible `INDEX_LENGTH` difference; both states report allocated index length as 0.00 MB. The execution plans provide the important structural proof:

| State | Type | Key | Extra |
|---|---|---|---|
| Fat index | range | `idx_fat_covering` | `Using where; Using index` |
| Lean index | range | `idx_lean_search` | `Using index condition` |

The final `SHOW INDEX` confirms that only the primary key and `idx_lean_search` remain. On a production-scale table, compare `INDEX_LENGTH` and filesystem usage using the real telemetry volume.

## Design boundary

A covering index is not always wrong. For a small, mostly-read `Countries` reference table, the write penalty may be negligible and avoiding table lookups can be worthwhile. For SmartFactory's continuous append workload, the lean index is the better balance between read latency, insert throughput, RAM, and cloud storage.

