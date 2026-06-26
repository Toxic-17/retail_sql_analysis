-- ============================================================
-- Sales Trend Analysis
-- Monthly revenue trend, year-over-year growth, and a 3-month moving
-- average — all via window functions (LAG, AVG ... OVER).
-- ============================================================

-- 1) Monthly revenue, order count, and average order value
WITH monthly AS (
    SELECT
        DATE_FORMAT(o.order_date, '%Y-%m') AS month,
        SUM(oi.quantity * oi.unit_price)   AS revenue,
        COUNT(DISTINCT o.order_id)         AS orders
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY month
)
SELECT
    month,
    ROUND(revenue, 2)            AS revenue,
    orders,
    ROUND(revenue / orders, 2)   AS avg_order_value,
    -- 3-month trailing moving average (smooths month-to-month noise)
    ROUND(AVG(revenue) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS revenue_3mo_moving_avg
FROM monthly
ORDER BY month;

-- 2) Year-over-year growth by month (LAG across the same calendar month, prior year)
WITH monthly AS (
    SELECT
        YEAR(o.order_date)  AS yr,
        MONTH(o.order_date) AS mo,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY yr, mo
)
SELECT
    yr, mo,
    ROUND(revenue, 2) AS revenue,
    ROUND(LAG(revenue) OVER (PARTITION BY mo ORDER BY yr), 2) AS revenue_same_month_prior_year,
    ROUND(
        (revenue - LAG(revenue) OVER (PARTITION BY mo ORDER BY yr)) * 100.0
        / LAG(revenue) OVER (PARTITION BY mo ORDER BY yr), 2
    ) AS yoy_growth_pct
FROM monthly
ORDER BY yr, mo;

-- 3) Annual summary with YoY growth
WITH yearly AS (
    SELECT YEAR(o.order_date) AS yr,
           SUM(oi.quantity * oi.unit_price) AS revenue,
           COUNT(DISTINCT o.order_id) AS orders,
           COUNT(DISTINCT o.customer_id) AS active_customers
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY yr
)
SELECT
    yr, ROUND(revenue, 2) AS revenue, orders, active_customers,
    ROUND(revenue / orders, 2) AS avg_order_value,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY yr)) * 100.0 / LAG(revenue) OVER (ORDER BY yr), 2) AS yoy_growth_pct
FROM yearly
ORDER BY yr;

-- 4) Revenue trend by region and quarter (joins + aggregation)
SELECT
    c.region,
    CONCAT(YEAR(o.order_date), '-Q', QUARTER(o.order_date)) AS year_quarter,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue,
    COUNT(DISTINCT o.order_id) AS orders
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'Completed'
GROUP BY c.region, year_quarter
ORDER BY c.region, year_quarter;

-- 5) Day-of-week sales pattern (operational insight: staffing/promo timing)
SELECT
    DAYNAME(o.order_date) AS day_of_week,
    ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.quantity * oi.unit_price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'Completed'
GROUP BY day_of_week
ORDER BY revenue DESC;
