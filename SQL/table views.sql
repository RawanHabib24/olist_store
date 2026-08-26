/*base_cost = 5.0
cost_per_km = 0.01
cost_per_kg = 1.0
*/

--suppose the year is 2019
--customers :
------------------------------------------------------
CREATE VIEW order_base AS (
    SELECT 
        o.order_id,
        c.customer_unique_id,
        o.order_purchase_timestamp,
        pay.total_payment AS payment_value
    FROM orders AS o
    INNER JOIN customers AS c ON o.customer_id = c.customer_id
    INNER JOIN (
        SELECT order_id, SUM(payment_value) AS total_payment
        FROM order_payments
        GROUP BY order_id
    ) AS pay ON o.order_id = pay.order_id
    WHERE o.order_status = 'delivered'
)
------------------------------------------------------
CREATE VIEW customer_segment AS 
WITH customers_RFM AS(
    SELECT 
        ob.customer_unique_id,
        customer_zip_code_prefix,
        customer_state,
        customer_city,
        MIN(ob.order_purchase_timestamp) AS first_purchase,
        MAX(ob.order_purchase_timestamp) AS last_purchase,
        DATEDIFF(DAY, MAX(ob.order_purchase_timestamp), '2018-11-01') AS recency_days,
        DATEDIFF(DAY, MIN(ob.order_purchase_timestamp), MAX(ob.order_purchase_timestamp)) AS customer_tenure_days,
        COUNT(DISTINCT ob.order_id) AS freq,
        SUM(ob.payment_value) AS total_spend
    FROM order_base AS ob
    LEFT JOIN customers ON customers.customer_unique_id = ob.customer_unique_id
    GROUP BY ob.customer_unique_id, customer_zip_code_prefix, customer_state, customer_city
),
RFM_score AS (
SELECT *,
NTILE(3) OVER(ORDER BY recency_days DESC) AS recency_score,
NTILE(3) OVER(ORDER BY total_spend) AS monetary_score
FROM customers_RFM)
SELECT *,
CASE 
WHEN (recency_score = 3 AND monetary_score IN (2,3)) THEN 'Champions'
WHEN (recency_score = 3 AND monetary_score = 1 ) THEN 'New Customers'
WHEN (recency_score = 2 AND monetary_score IN (2,3)) THEN 'Loyal'
WHEN (recency_score = 2 AND monetary_score = 1) THEN 'New Customers'
WHEN (recency_score = 1 AND monetary_score IN (2,3)) THEN 'At Risk Customers'
ELSE 'Lost Customers'
END AS RM_segment, 
CASE 
WHEN recency_score = 1 THEN 'Churned'
ELSE 'Active'
END AS recency_segment,
CASE 
WHEN (monetary_score = 3) THEN 'High Value'
WHEN (monetary_score = 2) THEN 'Medium Value'
ELSE 'Low Value'
END AS monetary_segment,
CASE 
WHEN freq = 1 THEN 'One-Time Buyer'
ELSE 'Repeat Buyer'
END AS buyer_type 
FROM RFM_score
------------------------------------------------------
CREATE VIEW customer_status AS 
WITH first_purchase AS (
    SELECT 
        customer_unique_id,
        MIN(order_purchase_timestamp) AS first_purchase_date
    FROM orders
    INNER JOIN customers 
        ON orders.customer_id = customers.customer_id
    GROUP BY customer_unique_id 
),
monthly_orders AS (
    SELECT 
        c.customer_unique_id,
        orders.order_id,
        order_purchase_timestamp,
        FORMAT(order_purchase_timestamp, 'yyyy-MM') AS order_month,
        FORMAT(fp.first_purchase_date, 'yyyy-MM') AS first_purchase_month
    FROM orders 
    INNER JOIN customers AS c
        ON orders.customer_id = c.customer_id
    INNER JOIN first_purchase AS fp 
        ON c.customer_unique_id = fp.customer_unique_id
)
SELECT 
    order_month,
    CASE 
        WHEN order_month = first_purchase_month THEN 'New'
        ELSE 'Returning'
    END AS customer_status,
    COUNT(DISTINCT customer_unique_id) AS num_customers
FROM monthly_orders
GROUP BY 
    order_month,
    CASE 
        WHEN order_month = first_purchase_month THEN 'New'
        ELSE 'Returning'
    END
---------------------------------------------------------------
--customer growth 
CREATE VIEW customers_growth AS 
SELECT YEAR(order_purchase_timestamp) AS purchase_year,
COUNT(DISTINCT customer_unique_id) AS total_customers, 
COUNT(orders.order_id) AS total_orders, 
ROUND(
CAST(
(COUNT(orders.order_id) - COUNT(DISTINCT customer_unique_id))*100.00
/COUNT(DISTINCT customer_unique_id) AS FLOAT),2) AS customer_repeat_perc
FROM customers
LEFT JOIN orders
ON orders.customer_id = customers.customer_id
GROUP BY YEAR(order_purchase_timestamp);
-----------------------------
CREATE VIEW customers_state_distribution AS
SELECT 
customer_state,
RM_segment, 
COUNT(RM_segment) AS total_customers,
SUM(COUNT(RM_segment)) OVER (PARTITION BY RM_segment) AS total_share
FROM customer_segment
GROUP BY RM_segment , customer_state;
----------------------------------
-----orders & problems
CREATE VIEW canceled_orders AS 
SELECT *,
CASE 
    WHEN order_delivered_customer_date != '1999-01-01 00:00:00.0000000' 
        THEN 'Returned After Delivery'
    WHEN order_approved_at = '1999-01-01 00:00:00.0000000' 
        THEN 'Canceled Before Approval'
    WHEN order_delivered_customer_date = '1999-01-01 00:00:00.0000000'
        AND order_delivered_carrier_date != '1999-01-01 00:00:00.0000000' 
        THEN 'Canceled In Transit'
    ELSE 'Canceled After Approval, Before Shipment'
END AS cancelation_reason
FROM orders 
WHERE order_status = 'canceled';
-----------------------------------------------------------------------------
--delivery performance
CREATE VIEW delivery AS 
WITH first_item AS (
    SELECT
        order_id,
        seller_id,
        distance_km,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_item_id) AS rn
    FROM order_items
),
delivery AS (
    SELECT
        o.order_status,
        o.order_id,
        fi.distance_km,
        c.customer_state,
        fi.seller_id,
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        DATEDIFF(DAY, o.order_purchase_timestamp, o.order_approved_at) AS approving_days,
        DATEDIFF(DAY, o.order_approved_at, o.order_delivered_carrier_date) AS carrier_days,
        DATEDIFF(DAY, o.order_delivered_carrier_date, o.order_delivered_customer_date) AS carrier_customer_deliverd_days,
        DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) AS delivery_days,
        DATEDIFF(DAY, o.order_purchase_timestamp, o.order_estimated_delivery_date) AS estimated_delivery_days,
        DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) -
        DATEDIFF(DAY, o.order_purchase_timestamp, o.order_estimated_delivery_date) AS delay_days
    FROM orders AS o
    INNER JOIN first_item AS fi
        ON o.order_id = fi.order_id AND fi.rn = 1   -- صف واحد بس لكل أوردر
    INNER JOIN customers AS c
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
order_segment AS (
    SELECT *,
        AVG(approving_days) OVER (PARTITION BY seller_id) AS sellers_approving_avg,
        CASE 
            WHEN delay_days > 0 THEN 'Late-order'
            WHEN delay_days < 0 THEN 'Early-order'
            ELSE 'On-Time'
        END AS order_segment,
        CASE 
            WHEN delay_days < 0 THEN 'early'
            WHEN delay_days = 0 THEN 'on-time'
            WHEN delay_days <= 7 THEN '1 week'
            WHEN delay_days BETWEEN 8 AND 14 THEN '2 weeks'
            WHEN delay_days BETWEEN 15 AND 21 THEN '3 weeks'
            WHEN delay_days BETWEEN 22 AND 31 THEN '1 Month'
            ELSE '+1month'
        END AS late_type
    FROM delivery
)
SELECT *,
    CASE 
        WHEN approving_days > sellers_approving_avg THEN 'Late'
        WHEN approving_days < sellers_approving_avg THEN 'early'
        ELSE 'On-Time'
    END AS seller_late_type
FROM order_segment;
