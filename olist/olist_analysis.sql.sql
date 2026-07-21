USE olist;

/* ============================================================
   OLIST CUSTOMER RETENTION ANALYSIS
   Author: Victoria Johnson
   Business Question: What separates one-time buyers from 
   repeat customers, and what should Olist do about it?
   Dataset: 99,441 orders, 93,358 unique customers
============================================================ */

-- Query 1: Customer order frequency distribution
-- How many customers placed 1 order, 2 orders, 3 orders, etc.?

WITH 
customer_orders AS 
(SELECT c.customer_unique_id, 
COUNT(DISTINCT o.order_id) AS order_count 
FROM customers c 
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered' 
GROUP BY c.customer_unique_id)

SELECT order_count, 
COUNT(*) AS number_of_customers,
ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_customers
FROM customer_orders 
GROUP BY order_count 
ORDER BY order_count;

-- Query 2: Revenue contribution - one-time vs repeat customers
-- Do the rare repeat customers spend more per person?

WITH 
customer_orders AS 
(SELECT c.customer_unique_id, 
COUNT(DISTINCT o.order_id) AS order_count
FROM customers c 
JOIN orders o ON c.customer_id = o.customer_id 
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id),

customer_revenue AS 
(SELECT c.customer_unique_id, 
SUM(oi.price + oi.freight_value) AS total_spent
FROM customers c 
JOIN orders o ON c.customer_id = o.customer_id 
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered' 
GROUP BY c.customer_unique_id)

SELECT 
CASE WHEN co.order_count = 1 THEN 'One_Time' ELSE 'Repeat' END AS customer_type,
COUNT(*) AS customers,
ROUND(SUM(cr.total_spent), 2) AS total_revenue,
ROUND(SUM(cr.total_spent) * 100.0 / SUM(SUM(cr.total_spent)) OVER (), 2) AS pct_of_revenue,
ROUND(AVG(cr.total_spent), 2) AS avg_lifetime_spend
FROM customer_orders co
JOIN customer_revenue cr ON co.customer_unique_id = cr.customer_unique_id
GROUP BY customer_type;


-- Query 3: Top categories by customer type
-- Do repeat customers buy different things than one-timers?

WITH 
customer_orders AS 
(SELECT c.customer_unique_id, 
COUNT(DISTINCT o.order_id) AS order_count
FROM customers c 
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered' 
GROUP BY c.customer_unique_id),

customer_type AS
(SELECT customer_unique_id, 
CASE WHEN order_count = 1 THEN 'One_Time' ELSE 'Repeat' END AS customer_type
FROM customer_orders),

category_purchases AS 
(SELECT ct.customer_type, 
p.product_category_name AS category,
COUNT(DISTINCT o.order_id) AS total_orders, 
ROUND(SUM(oi.price + oi.freight_value), 2) AS total_revenue
FROM customer_type ct
JOIN customers c ON ct.customer_unique_id = c.customer_unique_id
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_status = 'delivered'
GROUP BY ct.customer_type, p.product_category_name),

ranked AS 
(SELECT *,
RANK() OVER (PARTITION BY customer_type ORDER BY total_revenue DESC) AS revenue_rank
FROM category_purchases)

SELECT customer_type, revenue_rank, category, total_orders, total_revenue 
FROM ranked
WHERE revenue_rank <= 5 
ORDER BY customer_type, revenue_rank;


-- Query 4: Review scores by customer type
-- Are one-time buyers leaving because of a bad experience?

WITH 
customer_orders AS 
(SELECT c.customer_unique_id,
COUNT(DISTINCT o.order_id) AS order_count
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id),

customer_type AS 
(SELECT customer_unique_id,
CASE WHEN order_count = 1 THEN 'One_Time' ELSE 'Repeat' END AS customer_type
FROM customer_orders)

SELECT 
ct.customer_type,
COUNT(DISTINCT ct.customer_unique_id) AS customers,
COUNT(DISTINCT r.review_id) AS reviews,
ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM customer_type ct
JOIN customers c ON ct.customer_unique_id = c.customer_unique_id
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
GROUP BY ct.customer_type;


-- Query 5: Days between purchases
-- For customers who DO come back, how long does it take?

WITH 
customer_orders AS 
(SELECT c.customer_unique_id,
o.order_id,
o.order_purchase_timestamp,
ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id 
ORDER BY o.order_purchase_timestamp) AS order_sequence,
LAG(o.order_purchase_timestamp) OVER (PARTITION BY c.customer_unique_id 
ORDER BY o.order_purchase_timestamp) AS previous_order_date
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered')

SELECT 
order_sequence,
COUNT(*) AS customers_at_this_order,
ROUND(AVG(DATEDIFF(order_purchase_timestamp, previous_order_date)), 1) AS avg_days_since_previous_order
FROM customer_orders
WHERE order_sequence > 1
GROUP BY order_sequence
ORDER BY order_sequence
LIMIT 5;