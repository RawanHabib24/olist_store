/*
fright_revenue_margin = 0.15
--2. Sales & Revenue Page
Core Questions:

1. What is the total revenue, and how has it trended month over month? (DONE)
2. Which product categories generate the most revenue (80/20 Pareto)? (DONE)
3. What is the average order value (AOV), and how does it vary by category?
4. Which states/regions drive the highest sales?
5. What payment methods do customers prefer, and does that affect order value?

KPIs:

* Total Revenue
* Month-over-Month (MoM) / Year-over-Year (YoY) Growth
* Average Order Value (AOV)
* Revenue by Category (Top 20% products = Pareto)
* Revenue by State/Region
* Payment Method Distribution */

--1. What is the total revenue, and how has it trended month over month? 
WITH monthly_sales AS (
    SELECT 
        YEAR(o.order_purchase_timestamp) AS years,
        MONTH(o.order_purchase_timestamp) AS months,
        SUM(oi.price + oi.freight_value) AS total_sales, 
        SUM(price*commission_rate + freight_value*0.15)  AS total_revenue ,
        COUNT(customer_unique_id) AS total_customers
    FROM order_items AS oi
    INNER JOIN orders AS o
        ON o.order_id = oi.order_id
    INNER JOIN customers AS c
    ON c.customer_id = o.customer_id
    INNER JOIN products AS p
    ON p.product_id = oi.product_id
    WHERE order_status = 'delivered'
    GROUP BY 
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp)

)
SELECT 
years, 
months,
total_sales,
total_revenue,
NULLIF(LAG(total_revenue) OVER(PARTITION BY years ORDER BY years , months),0) AS prev_year_revenue,
NULLIF(LAG(total_sales) OVER(PARTITION BY years ORDER BY years , months),0) AS prev_year_sales,
CAST(
        (total_sales - LAG(total_sales) OVER (PARTITION BY years ORDER BY years , months)) * 100.0
        / NULLIF(LAG(total_sales) OVER (PARTITION BY years ORDER BY years , months), 0)
        AS DECIMAL(10,2)
    ) AS yoy_sales_growth_pct,
CAST(
        (total_revenue - LAG(total_revenue) OVER (PARTITION BY years ORDER BY years , months)) * 100.0
        / NULLIF(LAG(total_revenue) OVER (PARTITION BY years ORDER BY years , months), 0)
        AS DECIMAL(10,2)
    ) AS yoy_revenue_growth_pct,
CAST(
        (total_customers - LAG(total_customers) OVER (PARTITION BY years ORDER BY years , months)) * 100.0
        / NULLIF(LAG(total_customers) OVER (PARTITION BY years ORDER BY years , months), 0)
        AS DECIMAL(10,2)
    ) AS yoy_customer_growth_pct
FROM monthly_sales
ORDER BY years, months
---------------------------
--2. Which product categories generate the most revenue
CREATE VIEW category_revenue AS
WITH category_revenue AS (
    SELECT 
        p.product_category_name AS category,
        SUM(oi.price + oi.freight_value) AS total_revenue
    FROM order_items AS oi
    INNER JOIN products AS p
        ON p.product_id = oi.product_id
    GROUP BY p.product_category_name
),
ranked_categories AS (
    SELECT 
        category,
        total_revenue,
        RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        total_revenue * 100.0 / SUM(total_revenue) OVER () AS pct_of_total,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) * 100.0 
            / SUM(total_revenue) OVER () AS cumulative_pct
    FROM category_revenue
)
SELECT 
    revenue_rank,
    category,
    total_revenue,
    CAST(pct_of_total AS DECIMAL(10,2)) AS pct_of_total,
    CAST(cumulative_pct AS DECIMAL(10,2)) AS cumulative_pct,
    CASE 
        WHEN cumulative_pct <= 80 THEN 'Top 80% (Pareto)'
        ELSE 'Remaining 20%'
    END AS pareto_group
FROM ranked_categories

--------------------------------
--3-What is the average order value (AOV), and how does it vary by category
SELECT product_category_name,
AVG(price+freight_value) AS AOV
FROM order_items AS oi
INNER JOIN products AS p
ON p.product_id = oi.product_id
GROUP BY product_category_name
ORDER BY AOV DESC
--------------------------------
--4- Which states drive the highest sales?
SELECT customer_state,
SUM(price+freight_value) AS total_sales,
SUM(price+freight_value) *100.0 / SUM(SUM(price+freight_value)) OVER() AS ds,
SUM(freight_value*.15) AS fright_revenue
FROM customers AS c
INNER JOIN orders  AS o
ON o.customer_id = c.customer_id
INNER JOIN order_items  AS oi
ON oi.order_id = o.order_id
GROUP BY customer_state
ORDER BY fright_revenue DESC
----------------------------------
--5-What payment methods do customers prefer, and does that affect order value?
SELECT 
    payment_type,
    COUNT(DISTINCT order_id) AS total_orders,
    AVG(payment_value) AS avg_order_value,
    AVG(payment_installments) AS avg_installments
FROM order_payments
GROUP BY payment_type
ORDER BY avg_order_value DESC;
----------------------------
/*KPIs:
* Total Revenue
* Month-over-Month (MoM) / Year-over-Year (YoY) Growth
* Average Order Value (AOV)
* Revenue by Category (Top 20% products = Pareto)
* Revenue by State/Region
* Payment Method Distribution*/





