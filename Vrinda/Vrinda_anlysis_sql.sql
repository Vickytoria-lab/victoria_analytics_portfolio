/* ============================================================
   VRINDA STORE REVENUE ANALYSIS - 2022
   Author: Victoria Johnson
   Purpose: Diagnose 20% revenue decline from March to November
   Dataset: 31,047 orders, vrinda.vrindastoredata
============================================================== */

USE vrinda;


-- Query 1 - Monthly Revenue Trend
-- Establishes the shape of the decline across 2022
SELECT 
    MONTH(Date) AS month_number,
    MONTHNAME(Date) AS month_name,
    COUNT(*) AS total_orders,
    SUM(Amount) AS revenue,
    ROUND(AVG(Amount), 2) AS avg_order_value
FROM vrindastoredata
WHERE Status = 'Delivered'
GROUP BY MONTH(Date), MONTHNAME(Date)
ORDER BY month_number;


-- Query 2 - Channel Performance: March vs November
-- Identifies which channels bled the most using conditional aggregation
WITH channel_months AS (SELECT Channel,
SUM(CASE WHEN MONTH(Date) = 3 THEN Amount ELSE 0 END) AS march_revenue,
SUM(CASE WHEN MONTH(Date) = 11 THEN Amount ELSE 0 END) AS november_revenue
FROM vrindastoredata WHERE Status = 'Delivered' GROUP BY Channel)
SELECT Channel,
march_revenue,
november_revenue,
november_revenue - march_revenue AS revenue_change,
ROUND(((november_revenue - march_revenue) * 100.0 / march_revenue), 2) AS pct_change
FROM channel_months ORDER BY pct_change;


-- Query 3 - Category Performance: March vs November
WITH category_months AS (SELECT Category,
SUM(CASE WHEN MONTH(Date) = 3 THEN Amount ELSE 0 END) AS march_revenue,
SUM(CASE WHEN MONTH(Date) = 11 THEN Amount ELSE 0 END) AS november_revenue
FROM vrindastoredata WHERE Status = 'Delivered' GROUP BY Category)
SELECT Category,
march_revenue,
november_revenue,
november_revenue - march_revenue AS revenue_change,
ROUND(((november_revenue - march_revenue) * 100.0 / march_revenue), 2) AS pct_change
FROM category_months ORDER BY revenue_change;


-- Query 4 - Top 3 Categories per Channel (CTE + Window Function)
WITH ranked_categories AS (SELECT Channel, Category, SUM(Amount) AS revenue,
RANK() OVER (PARTITION BY Channel ORDER BY SUM(Amount) DESC) AS category_rank
FROM vrindastoredata where Status = 'Delivered'
GROUP BY Channel, Category)
SELECT * FROM ranked_categories WHERE category_rank <= 3
ORDER BY Channel, category_rank;


-- Query 5 - Demographic Segmentation: March vs November
WITH gender_months AS (SELECT Gender, AgeGroup, SUM(CASE WHEN MONTH(Date) = 3 THEN Amount ELSE 0 END) AS march_revenue,
SUM(CASE WHEN MONTH(Date) = 11 THEN Amount ELSE 0 END) AS november_revenue
FROM vrindastoredata WHERE Status = 'Delivered' GROUP BY Gender, AgeGroup)
SELECT Gender, AgeGroup, march_revenue, november_revenue, november_revenue - march_revenue AS revenue_change,
ROUND(((november_revenue - march_revenue) * 100.0 / march_revenue), 2) AS pct_change
FROM gender_months ORDER BY pct_change;


-- Query 6 - Stress Test: Women Customers by Channel
WITH women_channel_march_nov AS (SELECT Channel,
SUM(CASE WHEN MONTH(Date) = 3 THEN Amount ELSE 0 END) AS march_revenue,
SUM(CASE WHEN MONTH(Date) = 11 THEN Amount ELSE 0 END) AS november_revenue
FROM vrindastoredata WHERE Status = 'Delivered'
AND Gender = 'Women' GROUP BY Channel)
SELECT Channel, 
march_revenue, 
november_revenue,
november_revenue - march_revenue AS revenue_change,
ROUND(((november_revenue - march_revenue) * 100.0 / march_revenue), 2) AS pct_change
FROM women_channel_march_nov
ORDER BY revenue_change;