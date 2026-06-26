-- ============================================================
-- Query Performance Optimization — Indexing
--
-- Four representative business queries, benchmarked BEFORE and AFTER
-- adding targeted indexes. None of these queries are sped up "for free"
-- by the primary keys or foreign-key constraints already in 01_schema.sql
-- (SHOW INDEX confirms customer_id, store_id, order_id and product_id
-- already have FK-driven indexes — these four indexes are genuinely new).
--
-- Actual measured results (rows examined + execution time, captured via
-- EXPLAIN ANALYZE) are in notebooks/Retail_SQL_Analysis.ipynb and the
-- project README — this file documents the queries and the fix.
-- ============================================================

-- ---- Query 1: orders in a date range, filtered by status ------------
-- (a daily/weekly ops report — "show me completed orders this quarter")
EXPLAIN ANALYZE
SELECT order_id, customer_id, order_date, order_status
FROM orders
WHERE order_date BETWEEN '2025-01-01' AND '2025-03-31'
  AND order_status = 'Completed';

-- ---- Query 2: a single customer's order history within a date range --
-- (customer service / "show this customer's recent orders")
EXPLAIN ANALYZE
SELECT order_id, order_date, order_status
FROM orders
WHERE customer_id = 4821
  AND order_date >= '2024-01-01'
ORDER BY order_date DESC;

-- ---- Query 3: customer lookup by email --------------------------------
-- (login / account lookup — one of the most common query patterns in
-- any retail system, and one of the easiest to forget to index)
EXPLAIN ANALYZE
SELECT customer_id, first_name, last_name, city
FROM customers
WHERE email = 'ira.pillai4820@example.com';

-- ---- Query 4: a store's regional sales report over a date range -------
EXPLAIN ANALYZE
SELECT order_id, order_date, order_status
FROM orders
WHERE store_id = 7
  AND order_date BETWEEN '2025-01-01' AND '2025-06-30';

-- ============================================================
-- The fix: four targeted indexes
-- ============================================================

CREATE INDEX idx_orders_date_status   ON orders(order_date, order_status);
CREATE INDEX idx_orders_customer_date ON orders(customer_id, order_date);
CREATE INDEX idx_customers_email      ON customers(email);
CREATE INDEX idx_orders_store_date    ON orders(store_id, order_date);

-- Re-run the same four EXPLAIN ANALYZE statements above after this point
-- to see each query plan switch from a full table scan to an index range
-- scan, and the corresponding drop in actual execution time.

-- Note: once idx_orders_customer_date and idx_orders_store_date exist,
-- MySQL/InnoDB uses them to satisfy the fk_orders_customer / fk_orders_store
-- foreign key constraints (since each has its FK column as the leftmost
-- index column) and will refuse to DROP them ("needed in a foreign key
-- constraint") unless another index can take over that role. Good to know
-- before trying to tear down or rebuild indexes on a live FK-constrained
-- table.
