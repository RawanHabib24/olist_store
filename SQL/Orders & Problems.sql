/*
ليه ممكن يتلغي أوردر بعد الموافقة وقبل الشحن؟
دي فعلاً منطقة "رمادية" مثيرة للاهتمام لأن الدفع اتوافق عليه بالفعل. أشهر الأسباب اللي بتحصل في e-commerce:
نفاد المخزون بعد الموافقة: البائع اكتشف إن المنتج مش موجود فعليًا وقت ما جهز الأوردر للشحن
مشكلة لوجستية عند البائع: تأخر كبير أو عجز عن التغليف/الشحن في الوقت المحدد
العميل غيّر رأيه أو لقى الأوردر مكرر: طلب إلغاء بعد الدفع مباشرة
مشكلة في العنوان أو التوصيل اتكشفت بعد الموافقة
مراجعة احتيال (fraud review): أحيانًا الدفع بيتوافق أوتوماتيكيًا الأول، وبعدين نظام مكافحة الاحتيال بيوقف الأوردر
Timeout سياسة Olist نفسها: لو البائع اتأخر كتير عن تسليم الشحنة للـ carrier، النظام ممكن يلغي الأوردر تلقائيًا
*/
--KPIs:
--Order Status Breakdown (delivered, canceled, unavailable, etc.) (done)
SELECT order_status , 
COUNT(DISTINCT order_id) AS total_orders,
COUNT(DISTINCT order_id)*100.0 / SUM(COUNT(*)) OVER()
FROM orders
GROUP BY order_status
ORDER BY  total_orders DESC;
--
--Average Review Score (DONE)
SELECT AVG(review_score)
FROM order_reviews;
-- % of Orders with Low Reviews (1–2 stars) (Done)
SELECT CASE
WHEN (review_score = 1 OR review_score = 2) THEN 'Low review_score'
ELSE 'High review score'
END AS score_type,
COUNT(DISTINCT order_id)*100.0 / SUM(COUNT(*)) OVER() AS Score_distribution
FROM order_reviews
GROUP BY CASE
WHEN (review_score = 1 OR review_score = 2) THEN 'Low review_score'
ELSE 'High review score' END
--Complaint Category Breakdown (using your Delivery/Quality/Price/etc. classification) (Done)
CREATE VIEW compliant_category AS
WITH total_reviews AS (
    SELECT 
        review_class,
        COUNT(DISTINCT order_id) AS total_orders
    FROM  order_reviews
    GROUP BY review_class
),
low_reviews AS (
    SELECT 
        review_class,
        COUNT(DISTINCT order_id) AS total_low_orders
    FROM  order_reviews
    WHERE review_score IN (1, 2)
    GROUP BY review_class
    
)
SELECT tr.review_class, 
total_orders,
total_low_orders,
total_low_orders *100.0 / total_orders AS ds
FROM total_reviews AS tr
INNER JOIN low_reviews AS tlr
ON tr.review_class = tlr .review_class;
-- Order Problem Rate by Seller/Region (DONE)
CREATE VIEW sellers_bad_rate AS
SELECT seller_id,
AVG(review_score) avg_score,
COUNT(oi.order_id) AS total_orders
FROM order_items AS oi
INNER JOIN order_reviews AS r
ON oi.order_id = r.order_id
GROUP BY seller_id
HAVING AVG(review_score) IN (1,2)

-- 1-What percentage of orders are canceled, undelivered, or returned? (DONE)
SELECT 
cancelation_reason,
COUNT(cancelation_reason) AS total_orders,
COUNT(cancelation_reason)*100.0 / (SELECT COUNT(*)
                                  FROM canceled_orders) AS Distribution
FROM canceled_orders 
GROUP BY cancelation_reason
---------------------------
-- 2-What are the most common reasons customers give low review scores? DONE()
WITH orders_feedback AS (
SELECT review_id,
order_id,
review_comment_message,
review_score,
main_category
FROM order_reviews
WHERE (review_score = 1 OR review_score = 2 )
AND review_comment_message != 'No Comment'
)
SELECT main_category,
COUNT(DISTINCT order_id)  AS total_orders,
COUNT(DISTINCT order_id)*100.00/SUM(COUNT(*)) OVER() AS Class_Distriution
FROM orders_feedback
GROUP BY main_category
ORDER BY COUNT(DISTINCT order_id) DESC
--
-- 3-Which categories have the highest complaint/order-problem rate?(DONE)
SELECT 
product_category_name,
COUNT(oi.order_id) AS total_orders, 
COUNT(oi.order_id)*100.0 / SUM(COUNT(oi.order_id)) OVER () AS orders_distribution
FROM products AS p
LEFT JOIN order_items AS oi
ON oi.product_id = p.product_id
LEFT JOIN order_reviews AS r
ON r.order_id = oi.order_id
WHERE review_score IN(1,2)
GROUP BY product_category_name 
ORDER BY orders_distribution DESC
--
-- 3- Which categories have the highest complaint/order-problem rate? (DONE)
CREATE VIEW categories_compiliant_rate AS
SELECT 
    p.product_category_name,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(DISTINCT CASE WHEN r.review_score IN (1,2) THEN oi.order_id END) AS bad_orders,
    COUNT(DISTINCT CASE WHEN r.review_score IN (1,2) THEN oi.order_id END) * 100.0 
        / COUNT(DISTINCT oi.order_id) AS complaint_rate
FROM products AS p
INNER JOIN order_items AS oi
    ON oi.product_id = p.product_id
INNER JOIN order_reviews AS r
    ON r.order_id = oi.order_id
GROUP BY p.product_category_name
-- 4- Are order problems linked to specific sellers? (with comparison to overall average) DONE
CREATE VIEW sellers_problems AS 
WITH sellers_total AS (
    SELECT 
        oi.seller_id,
        COUNT(DISTINCT oi.order_id) AS total_orders
    FROM order_items AS oi
    INNER JOIN order_reviews AS r
        ON oi.order_id = r.order_id
    GROUP BY oi.seller_id
),
sellers_low_reviews AS (
    SELECT 
        oi.seller_id,
        COUNT(DISTINCT oi.order_id) AS low_review_orders
    FROM order_items AS oi
    INNER JOIN order_reviews AS r
        ON oi.order_id = r.order_id
    WHERE r.review_score IN (1, 2)
    GROUP BY oi.seller_id
),
seller_rates AS (
    SELECT 
        t.seller_id,
        t.total_orders,
        lr.low_review_orders,
        lr.low_review_orders * 100.0 / t.total_orders AS low_reviews_rate
    FROM sellers_total AS t
    INNER JOIN sellers_low_reviews AS lr
        ON t.seller_id = lr.seller_id
    WHERE t.total_orders >= 10
),
overall_avg AS (
    SELECT 
        SUM(low_review_orders) * 100.0 / SUM(total_orders) AS overall_rate
    FROM seller_rates
)
SELECT 
    sr.seller_id,
    sr.total_orders,
    sr.low_review_orders,
    ROUND(sr.low_reviews_rate, 1) AS low_reviews_rate,
    ROUND(oa.overall_rate, 1) AS overall_avg_rate,
    ROUND(sr.low_reviews_rate - oa.overall_rate, 1) AS diff_from_avg,
    CASE 
        WHEN sr.low_reviews_rate >= oa.overall_rate * 2 THEN 'High Risk'
        WHEN sr.low_reviews_rate >= oa.overall_rate * 1.5 THEN 'Above Average'
        ELSE 'Normal'
    END AS risk_flag
FROM seller_rates AS sr
CROSS JOIN overall_avg AS oa
--
-- 5- What is the overall customer satisfaction score, and how does it trend over time? (DONE)
SELECT YEAR(order_purchase_timestamp) AS years,
MONTH(order_purchase_timestamp) AS months,
AVG(review_score) AS avg_score
FROM order_reviews AS r
INNER JOIN orders AS o
ON r.order_id = o.order_id
GROUP BY YEAR(order_purchase_timestamp),
MONTH(order_purchase_timestamp)
ORDER BY years , months
