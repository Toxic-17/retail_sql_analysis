-- ============================================================
-- Customer Segmentation — RFM Analysis
-- (Recency, Frequency, Monetary)
--
-- Classic marketing-analytics segmentation, built entirely in SQL using
-- CTEs and window functions (NTILE for quintile scoring). Only
-- 'Completed' orders count toward a customer's behavior — cancelled and
-- returned orders are not loyalty signals.
-- ============================================================

WITH customer_orders AS (
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id)                          AS frequency,
        SUM(oi.quantity * oi.unit_price)                    AS monetary,
        MAX(o.order_date)                                   AS last_order_date,
        DATEDIFF((SELECT MAX(order_date) FROM orders), MAX(o.order_date)) AS recency_days
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY o.customer_id
),
rfm_scores AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        -- quintile 5 = best in every dimension (most recent / most frequent / highest spend)
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)     AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)      AS m_score
    FROM customer_orders
),
rfm_segmented AS (
    SELECT
        *,
        (r_score + f_score + m_score) AS rfm_total,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN f_score >= 4 AND r_score >= 3                  THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2                  THEN 'New Customers'
            WHEN m_score >= 4 AND r_score <= 3                  THEN 'Big Spenders (at risk of drift)'
            WHEN r_score <= 2 AND f_score >= 3                  THEN 'At Risk'
            WHEN r_score <= 2 AND f_score <= 2                  THEN 'Lost / Lapsed'
            ELSE 'Regular'
        END AS segment
    FROM rfm_scores
)
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.region,
    s.recency_days,
    s.frequency,
    ROUND(s.monetary, 2) AS monetary,
    s.r_score, s.f_score, s.m_score, s.rfm_total,
    s.segment
FROM rfm_segmented s
JOIN customers c ON c.customer_id = s.customer_id
ORDER BY s.rfm_total DESC;

-- Segment-level summary: how many customers in each segment, and their
-- combined value — this is the table a marketing team would actually act on.
WITH customer_orders AS (
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.quantity * oi.unit_price) AS monetary,
        DATEDIFF((SELECT MAX(order_date) FROM orders), MAX(o.order_date)) AS recency_days
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY o.customer_id
),
rfm_scores AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)     AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)      AS m_score
    FROM customer_orders
),
rfm_segmented AS (
    SELECT *,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN f_score >= 4 AND r_score >= 3                  THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2                  THEN 'New Customers'
            WHEN m_score >= 4 AND r_score <= 3                  THEN 'Big Spenders (at risk of drift)'
            WHEN r_score <= 2 AND f_score >= 3                  THEN 'At Risk'
            WHEN r_score <= 2 AND f_score <= 2                  THEN 'Lost / Lapsed'
            ELSE 'Regular'
        END AS segment
    FROM rfm_scores
)
SELECT
    segment,
    COUNT(*)                                   AS num_customers,
    ROUND(AVG(monetary), 2)                    AS avg_lifetime_value,
    ROUND(SUM(monetary), 2)                    AS total_segment_value,
    ROUND(SUM(monetary) * 100.0 / SUM(SUM(monetary)) OVER (), 2) AS pct_of_total_value
FROM rfm_segmented
GROUP BY segment
ORDER BY total_segment_value DESC;
