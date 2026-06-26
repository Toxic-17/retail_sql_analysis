# SQL-Based Retail Data Analysis (MySQL)

A normalized retail transactional database, designed and analyzed directly
in **MySQL** — customer segmentation, sales trend analysis, product
performance, and a real, measured query-optimization exercise.

## What's in this project

```
retail_sql_analysis/
├── data/                          generated CSVs (the source data)
├── sql/
│   ├── 01_schema.sql               DDL: 6 tables, PK/FK constraints
│   ├── 02_customer_segmentation.sql   RFM analysis (CTEs + NTILE)
│   ├── 03_sales_trend_analysis.sql    monthly trends, YoY growth (LAG, moving avg)
│   ├── 04_product_performance.sql     top products/categories (RANK, joins)
│   └── 05_query_optimization.sql      before/after indexing benchmark queries
├── notebooks/
│   ├── Retail_SQL_Analysis.ipynb   full analysis, already executed against live MySQL
│   └── Retail_SQL_Analysis.html    same notebook, viewable without Jupyter
├── generate_retail_data.py         generates customers/products/stores/categories
├── generate_orders.py              generates the large orders + order_items tables
├── load_data.py                    bulk-loads the CSVs into MySQL
└── benchmark_optimization.py       the before/after indexing benchmark
```

## 1. The database

A proper normalized (3NF) relational schema — six tables with real
primary/foreign key constraints, the kind of schema an actual retail
order-management system would run on (as opposed to a BI star schema):

`customers` (12,000) · `categories` (10) · `products` (150) ·
`stores` (25) · `orders` (**150,000**) · `order_items` (**~297,000**)

3 years of order history (2023–2025) with realistic seasonality (Oct/Nov
festive-season spike), YoY growth, and a 91/5/4% Completed/Cancelled/Returned
order-status split. Large enough that indexing produces a genuine,
measurable performance difference — see Section 3.

## 2. The analysis (`sql/02` – `04`)

- **Customer segmentation (RFM)** — Recency/Frequency/Monetary scoring via
  `NTILE()` window functions over CTEs, combined into segments (Champions,
  Loyal Customers, At Risk, Lost/Lapsed, etc.)
- **Sales trend analysis** — monthly revenue with a 3-month moving average,
  year-over-year growth via `LAG()`, revenue by region/quarter, day-of-week
  patterns
- **Product & category performance** — top products by revenue (`RANK()`),
  category margin analysis, store performance ranked within region,
  return-rate by category, slow-moving inventory check

All of this runs live against the MySQL database in
`notebooks/Retail_SQL_Analysis.ipynb` — open the `.html` version if you
don't have Jupyter/MySQL installed, every chart and table is already baked in.

**Headline segmentation result:** "Champions" and "Loyal Customers" are a
minority of the 12,000 customers but contribute a disproportionate share
of total revenue — the RFM analysis quantifies exactly how much, and
separately quantifies how much revenue sits in the "At Risk" / "Lost"
segments as a recoverable win-back target.

## 3. Query performance optimization (`sql/05`, `benchmark_optimization.py`)

Four representative queries — an ops date-range report, a customer's order
history, a customer lookup by email, and a per-store sales report —
benchmarked with `EXPLAIN ANALYZE` **before and after** adding four
targeted indexes. `SHOW INDEX` was checked first to confirm none of these
get a "free" index from the existing primary/foreign keys.

| Query | Before | After | Speedup |
|---|---|---|---|
| Date range + status filter (ops report) | Table scan, 109ms | Index range scan, 26ms | **4.1x** |
| Customer order history | Index lookup, 0.05ms | Index range scan, 0.06ms | ~1x (already fast; see note) |
| Customer lookup by email | Table scan, 5.0ms | Index lookup, 0.02ms | **214x** |
| Store regional sales report | Index lookup, 10.3ms | Index range scan, 2.0ms | **5.2x** |

These are real, measured numbers (not estimates) — re-run
`python benchmark_optimization.py` yourself to reproduce them.

**Honest note on the customer-order-history query:** it was already fast
before adding `idx_orders_customer_date`, because `customer_id` already had
an index from its foreign-key constraint. The composite index's real value
shows up on wider date ranges and larger customer histories than this
single test case — which is itself a useful, real lesson: not every
"obvious" index pays off equally, and it's worth checking `EXPLAIN`
before assuming.

**A genuine MySQL behavior worth knowing**, discovered while building this:
once `idx_orders_customer_date` and `idx_orders_store_date` exist, InnoDB
uses them to satisfy the `fk_orders_customer` / `fk_orders_store` foreign
key constraints (since the FK column is the index's leftmost column) and
will refuse to `DROP` them — *"needed in a foreign key constraint"* — unless
another index can take over. Worth knowing before trying to tear down or
rebuild indexes on a live FK-constrained table in production.

**The trade-off**, stated explicitly rather than glossed over: every index
speeds up reads but adds overhead to every `INSERT`/`UPDATE` on that table
and consumes disk space. These four were chosen because they match query
patterns that are actually run often (reporting and lookups) — not added
indiscriminately.

## Reproducing from scratch

```bash
python generate_retail_data.py   # customers, products, stores, categories
python generate_orders.py        # orders + order_items (150K / ~297K rows)

mysql -u root -e "CREATE DATABASE IF NOT EXISTS retail_analysis;"
mysql -u root retail_analysis < sql/01_schema.sql
python load_data.py              # bulk-loads all CSVs via LOAD DATA LOCAL INFILE

python benchmark_optimization.py # before/after indexing benchmark

cd notebooks
jupyter nbconvert --to notebook --execute --inplace Retail_SQL_Analysis.ipynb
```

Requires a MySQL 8.0+ server with `local_infile` enabled
(`SET GLOBAL local_infile = 1;`) and the `pymysql` Python package.

All data is synthetically generated for this project — not real customer
or sales data.
