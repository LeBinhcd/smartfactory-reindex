# AI prompt log

## Prompt 1 — Covering index

**Question:** What is a covering index and why can it speed up a SELECT?

**Key result:** A covering index contains the search columns and every column needed by the query. MySQL can satisfy the query from the secondary index without fetching the clustered record, which can reduce random I/O. The index is wider and therefore more expensive to maintain.

## Prompt 2 — Clustered and secondary indexes

**Question:** How does InnoDB organize a primary key and a secondary index?

**Key result:** InnoDB stores the row data in the clustered primary-key index. A secondary-index record contains its indexed columns plus the primary-key value used to locate the full row. A non-covering query therefore performs a secondary lookup followed by a clustered-record lookup.

## Prompt 3 — Write penalty

**Question:** Why does adding payload columns to an index slow INSERT?

**Key result:** Each inserted row must be added to the secondary B-Tree. Wider entries require more page writes, buffer-pool memory, redo logging, and possible page splits. More index maintenance increases write latency and storage consumption.

## Prompt 4 — Lean index design

**Question:** Which columns should remain in the SmartFactory dashboard index?

**Key result:** Keep the columns used to filter and order the result: `(sensor_id, recorded_at)`. Do not include selected payload columns merely to force a covering plan when the workload is dominated by continuous inserts.

## Prompt 5 — EXPLAIN validation

**Question:** What should change after replacing the fat index?

**Key result:** `EXPLAIN` should identify `idx_lean_search` in `key`, retain a selective `range` or `ref` access pattern, and no longer report `Using index` in `Extra` because the selected payload columns require a clustered-table lookup.
