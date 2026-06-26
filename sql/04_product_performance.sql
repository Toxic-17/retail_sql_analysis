-- ============================================================
-- Product & Category Performance Analysis
-- ============================================================

-- 1) Top 15 products by revenue, with rank and contribution % (window functions)
WITH product_sales AS (
    SELECT
        p.product_id, p.product_name, cat.category_name,
        SUM(oi.quantity)                       AS units_sold,
        SUM(oi.quantity * oi.unit_price)       AS revenue,
        SUM(oi.quantity * (oi.unit_price - p.unit_cost)) AS profit
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    JOIN products p ON p.product_id = oi.product_id
    JOIN categories cat ON cat.category_id = p.category_id
    WHERE o.order_status = 'Completed'
    GROUP BY p.product_id, p.product_name, cat.category_name
)
SELECT
    product_id, product_name, category_name, units_sold,
    ROUND(revenue, 2) AS revenue, ROUND(profit, 2) AS profit,
    RANK() OVER (ORDER BY revenue DESC) AS revenue_rank,
    ROUND(revenue * 100.0 / SUM(revenue) OVER (), 2) AS pct_of_total_revenue
FROM product_sales
ORDER BY revenue_rank
LIMIT 15;

-- 2) Category performance summary
WITH cat_sales AS (
    SELECT
        cat.category_id, cat.category_name,
        SUM(oi.quantity) AS units_sold,
        SUM(oi.quantity * oi.unit_price) AS revenue,
        SUM(oi.quantity * (oi.unit_price - p.unit_cost)) AS profit,
        COUNT(DISTINCT o.order_id) AS orders_containing_category
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    JOIN products p ON p.product_id = oi.product_id
    JOIN categories cat ON cat.category_id = p.category_id
    WHERE o.order_status = 'Completed'
    GROUP BY cat.category_id, cat.category_name
)
SELECT
    category_name, units_sold,
    ROUND(revenue, 2) AS revenue,
    ROUND(profit, 2) AS profit,
    ROUND(profit * 100.0 / revenue, 2) AS margin_pct,
    orders_containing_category,
    ROUND(revenue * 100.0 / SUM(revenue) OVER (), 2) AS pct_of_total_revenue
FROM cat_sales
ORDER BY revenue DESC;

-- 3) Store performance — revenue per store, ranked within region
WITH store_sales AS (
    SELECT
        s.store_id, s.store_name, s.region,
        SUM(oi.quantity * oi.unit_price) AS revenue,
        COUNT(DISTINCT o.order_id) AS orders
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN stores s ON s.store_id = o.store_id
    WHERE o.order_status = 'Completed'
    GROUP BY s.store_id, s.store_name, s.region
)
SELECT
    store_name, region, orders, ROUND(revenue, 2) AS revenue,
    RANK() OVER (PARTITION BY region ORDER BY revenue DESC) AS rank_within_region
FROM store_sales
ORDER BY region, rank_within_region;

-- 4) Order cancellation / return rate by category (a quality/ops signal,
--    not just a sales one — uses ALL orders, not just Completed)
SELECT
    cat.category_name,
    COUNT(*) AS total_line_items,
    SUM(CASE WHEN o.order_status = 'Returned' THEN 1 ELSE 0 END) AS returned_items,
    ROUND(SUM(CASE WHEN o.order_status = 'Returned' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS return_rate_pct
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
JOIN categories cat ON cat.category_id = p.category_id
GROUP BY cat.category_name
ORDER BY return_rate_pct DESC;

-- 5) Products with no sales in the last 90 days (slow-moving inventory check)
SELECT p.product_id, p.product_name, cat.category_name, p.launch_date
FROM products p
JOIN categories cat ON cat.category_id = p.category_id
WHERE p.product_id NOT IN (
    SELECT DISTINCT oi.product_id
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_date >= (SELECT DATE_SUB(MAX(order_date), INTERVAL 90 DAY) FROM orders)
)
ORDER BY cat.category_name;
