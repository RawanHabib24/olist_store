--Customer behavior :
--KPIs:
-- 1-total unique customers:
SELECT COUNT(DISTINCT customer_unique_id) AS total_customers
FROM customers;
-- 2-Repeat Purchase Rate (%)
WITH repeated_customers AS (
    SELECT 
        customer_unique_id,
        COUNT(DISTINCT o.order_id) AS purchase_repeat,
        COUNT(*) OVER() AS total_customers,
        SUM(payment_value) AS total_spent
    FROM customers AS c
    INNER JOIN orders AS o ON o.customer_id = c.customer_id
    INNER JOIN order_payments AS op ON op.order_id = o.order_id
    GROUP BY customer_unique_id
),
customer_type AS (
    SELECT *,
        CASE 
            WHEN purchase_repeat = 1 THEN 'One-time buyers'
            WHEN purchase_repeat > 1 THEN 'Repeat buyers'
        END AS customer_type
    FROM repeated_customers
)
SELECT 
    customer_type,
    total_customers,
    CAST(COUNT(customer_type) AS DECIMAL(10,4)) / total_customers AS repeat_purchase_rate
FROM customer_type
WHERE customer_type = 'Repeat buyers'
GROUP BY customer_type, total_customers;
--------------------------------
-- 3-Average CLV = Average Order Value × Average Purchase Frequency × Average Customer Lifespan
-- Average Customer Lifespan = 1 / Churn Rate (for one time buyers)
WITH churn_count AS (
SELECT churn_status,
COUNT(customer_unique_id) AS churn_count,
SUM(COUNT(customer_unique_id)) OVER() AS total_customers
FROM customer_segment
GROUP BY churn_status
), 
AOV AS (
SELECT SUM(payment_value) / COUNT(DISTINCT order_id) AS avg_order_value
FROM order_payments
),
avg_freq AS (
SELECT CAST (AVG(freq) AS FLOAT )AS avg_purchase_frequency
FROM customer_segment
)
SELECT churn_status,
CAST(churn_count AS DECIMAL(10,4)) / total_customers AS churn_rate,
avg_order_value,
avg_purchase_frequency,
1/ (CAST(churn_count AS DECIMAL(10,4)) / total_customers) * avg_order_value * avg_purchase_frequency AS avg_clv
FROM churn_count
CROSS JOIN AOV 
CROSS JOIN avg_freq
WHERE churn_status = 'Churned';
--------------------------------------------
-- 2-Average CLV = Average Order Value × Average Purchase Frequency × Average Customer Lifespan
-- Average Customer Lifespan = 1 / Churn Rate (for more than one time buyers)
WITH churn_count AS (
SELECT churn_status,
COUNT(customer_unique_id) AS churn_count,
SUM(COUNT(customer_unique_id)) OVER() AS total_customers
FROM customer_segment
GROUP BY churn_status
), 
AOV AS (
SELECT SUM(payment_value) / COUNT(DISTINCT order_id) AS avg_order_value
FROM order_payments
),
avg_freq AS (
SELECT CAST (AVG(freq) AS FLOAT )AS avg_purchase_frequency
FROM customer_segment
WHERE freq > 1
)
SELECT churn_status,
CAST(churn_count AS DECIMAL(10,4)) / total_customers AS churn_rate,
avg_order_value,
avg_purchase_frequency,
1/ (CAST(churn_count AS DECIMAL(10,4)) / total_customers) * avg_order_value * avg_purchase_frequency AS avg_clv
FROM churn_count
CROSS JOIN AOV 
CROSS JOIN avg_freq
WHERE churn_status = 'Churned';
-------------------------------------------
-- 4- NEW VS returning customers
SELECT *
FROM customer_status
-----------------------------------------------------------
--5-Customer segments by RFM (e.g., Champions, At Risk, Lost)
SELECT customer_segment,
COUNT(customer_unique_id) AS total_customers
FROM customer_segment
GROUP BY customer_segment
ORDER BY total_customers DESC;
---------------------------------------------------------------------------------------------------------------------------------------------------
--core questions :
--who are our most valuable customers?
SELECT customer_unique_id,
CLV_segment ,
churn_status,
COUNT(customer_unique_id)  OVER() AS total_customers,
SUM(total_spend) AS total_spend
FROM customer_segment
GROUP BY CLV_segment, churn_status , customer_unique_id
ORDER BY total_spend DESC;
--------------------
--2- ARe High -Value Customers concentrated in specific states?
SELECT
customer_state,
CLV_segment,
COUNT(customer_unique_id) AS total_customers
FROM customer_segment
WHERE CLV_segment = 'High Value'
GROUP BY customer_state , CLV_segment
ORDER BY total_customers DESC;
------------------------------------
--3- Are there any specific states where customers are more likely to churn?
SELECT
customer_state,
churn_status,
COUNT(customer_unique_id) AS total_customers
FROM customer_segment
WHERE churn_status = 'Churned'
GROUP BY customer_state , churn_status
ORDER BY total_customers DESC;
------------------------------------
/*How many unique customers does Olist have, and is that number growing over time?*/
SELECT *
FROM customer_growth
/*What percentage of customers are repeat buyers vs. one-time buyers?*/
WITH repeated_customers AS (
    SELECT 
        customer_unique_id,
        COUNT(DISTINCT o.order_id) AS purchase_repeat,
        COUNT(*) OVER() AS total_customers,
        SUM(payment_value) AS total_spent
    FROM customers AS c
    INNER JOIN orders AS o ON o.customer_id = c.customer_id
    INNER JOIN order_payments AS op ON op.order_id = o.order_id
    GROUP BY customer_unique_id
),
customer_type AS (
    SELECT *,
        CASE 
            WHEN purchase_repeat = 1 THEN 'One-time buyers'
            WHEN purchase_repeat > 1 THEN 'Repeat buyers'
        END AS customer_type
    FROM repeated_customers
)
SELECT 
    customer_type,
    total_customers,
    CAST(COUNT(customer_type) AS DECIMAL(10,4))*100 / total_customers AS repeat_purchase_rate
FROM customer_type
GROUP BY customer_type, total_customers;
/*Which customers are most valuable (high spend , frequent orders)?
How do customers segment by recency, frequency, and monetary value (RFM)?
What is the average customer lifetime value (CLV)?*/
