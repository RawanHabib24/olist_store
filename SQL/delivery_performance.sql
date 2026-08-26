--DELIVERY PERFORMANCE
/*
3. Delivery Performance Page

Core Questions:

1- What is the average delivery time from purchase to delivery? (DONE)
2- What percentage of orders are delivered late vs. on time? (DONE)
3- Is there a gap between estimated and actual delivery dates? (DONE)
4- Do certain regions/states experience longer delivery delays? (DONE)
5- Does delivery time affect customer satisfaction (review score)? (DONE)

KPIs:

Average Delivery Time (days) (DONE)
On-Time Delivery Rate (%) (DONE)
Average Delay (actual − estimated delivery date) (DONE)
Delivery Time by State (DONE)
Correlation: Delivery Delay vs. Review Score (DONE)

*/
-- 1-What is the average delivery time from purchase to delivery?
----avg delivery time , avg_estimated_delivery_time
SELECT AVG(delivery_days) AS avg_delivery_days,
AVG(estimated_delivery_days) AS avg_estimated_delivery_days
FROM orders_delivery;
---------------avg_late_orders_days 
SELECT AVG(delay_days) AS avg_delivery_days,
AVG(estimated_delivery_days) AS avg_estimated_delivery_days
FROM orders_delivery
WHERE delay_days > 0;
----------------------
--late orders pct
SELECT 
    order_segment,
    COUNT(DISTINCT order_id) AS num_orders,
    CAST(COUNT(DISTINCT order_id) AS FLOAT) * 100 / SUM(COUNT(DISTINCT order_id)) OVER() AS pct
FROM delivery
GROUP BY order_segment
ORDER BY num_orders DESC;
----------------------------
--which state has the highest avg delay days
--4- Do certain regions/states experience longer delivery delays?
SELECT customer_state,
AVG(estimated_delivery_days) AS avg_state_days,
AVG(delay_days) AS avg_delay_days
FROM delivery
WHERE order_segment = 'Late-order'
GROUP BY customer_state
ORDER BY avg_delay_days DESC
--------------
--2- What percentage of orders are delivered late vs. on time?
SELECT order_segment,
COUNT(DISTINCT order_id) AS total_orders 
FROM orders_delivery
GROUP BY order_segment
-------------
--3-Is there a gap between estimated and actual delivery dates?
SELECT 
    AVG(estimated_delivery_days) AS avg_estimated_days,
    AVG(delivery_days) AS avg_actual_days,
    AVG(delay_days) AS avg_gap_days
FROM (
    SELECT DISTINCT 
        order_id, 
        estimated_delivery_days, 
        delivery_days, 
        delay_days
    FROM orders_delivery
) AS distinct_orders;
------------------------
--5- Does delivery time affect customer satisfaction (review score)?
SELECT CASE 
       WHEN(delay_days < 0) THEN 'early'
       WHEN(delay_days = 0) THEN 'on-time'
       WHEN(delay_days <= 7) THEN '1 week'
       WHEN(delay_days >= 8 AND delay_days <= 14) THEN '2 weeks'
       WHEN(delay_days >=15  AND delay_days <=21) THEN '3 weeks'
       WHEN(delay_days >=22 AND delay_days <= 31) THEN '1 Month'
       ELSE '+1month'
       END AS late_type,
AVG(review_score) AS avg_score
FROM orders_delivery AS od
INNER JOIN order_reviews AS r
ON r.order_id = od.order_id
GROUP BY CASE 
       WHEN(delay_days < 0) THEN 'early'
       WHEN(delay_days = 0) THEN 'on-time'
       WHEN(delay_days <= 7) THEN '1 week'
       WHEN(delay_days >= 8 AND delay_days <= 14) THEN '2 weeks'
       WHEN(delay_days >=15  AND delay_days <=21) THEN '3 weeks'
       WHEN(delay_days >=22 AND delay_days <= 31) THEN '1 Month'
       ELSE '+1month'
       END 
-------------------
SELECT COUNT(*) AS null_order_id_delivery
FROM delivery
WHERE order_id IS NULL;

SELECT COUNT(*) AS null_order_id_orders
FROM orders
WHERE order_id IS NULL;
---------------------
-- order_reviews عندها order_id مش موجود في delivery
SELECT COUNT(*) AS unmatched_reviews
FROM order_reviews AS r
LEFT JOIN delivery AS d ON r.order_id = d.order_id
WHERE d.order_id IS NULL;

-------------
-- delivery عندها order_id مش موجود في order_reviews  
SELECT COUNT(*) AS unmatched_delivery
FROM delivery AS d
LEFT JOIN order_reviews AS r ON d.order_id = r.order_id
WHERE r.order_id IS NULL;

