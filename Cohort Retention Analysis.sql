-- COHORT RETENTION ANALYSIS
-- SEGMENTED INTO TOP 20% AND 80% FOR COMPARISON WITH ALL CUSTOMERS COMBINED TOGETHER
CREATE OR REPLACE VIEW vw_cohort_retention_all AS
WITH first_purchase AS (
SELECT 
      Customer_ID,
       SUM(Quantity * Price) AS total_revenue,
      MIN(InvoiceDate) - INTERVAL(DAY(MIN(InvoiceDate)-1)) DAY AS first_order_date
FROM fact_sales
WHERE Customer_ID != 'GUEST'
GROUP BY Customer_ID),

rank_segment AS (
SELECT 
       Customer_ID,
       first_order_date,
      CASE WHEN NTILE(5) OVER(ORDER BY total_revenue DESC) = 1 THEN 'VIP(TOP 20%)' ELSE 'STANDARD(80%)' END AS segment
FROM first_purchase
 ),

month_period AS (
SELECT 
       r.segment,
       r.first_order_date,
       fs.InvoiceDate,
       fs.Customer_ID,
       (fs.Quantity * fs.Price) AS line_revenue,
       fs.ProductKey,
       TIMESTAMPDIFF(
       MONTH,
       r.first_order_date,
       (fs.InvoiceDate - INTERVAL(DAY(fs.InvoiceDate)-1) DAY) 
       )AS month_number
FROM fact_sales fs
LEFT JOIN rank_segment r
ON fs.Customer_ID = r.Customer_ID
WHERE fs.Customer_ID != 'GUEST'
),
all_activity AS(
SELECT 
        'ALL CUSTOMERS' AS segment,
        first_order_date,
		month_number,
       COUNT(DISTINCT Customer_ID) AS cohort_size,
		COUNT(DISTINCT ProductKey) AS unique_products_bought ,
       ROUND(SUM(line_revenue), 2) AS cohort_revenue
FROM month_period
GROUP BY first_order_date,month_number),

 segmented_activity AS (
SELECT 
       segment,
       first_order_date,
       month_number,
       COUNT(DISTINCT Customer_ID) AS cohort_size,
        COUNT(DISTINCT ProductKey) AS unique_products_bought,
       ROUND(SUM(line_revenue), 2) AS cohort_revenue
FROM month_period
GROUP BY segment, first_order_date, month_number
),
combined_activity AS (
    SELECT * FROM segmented_activity
    UNION ALL
    SELECT * FROM all_activity
)

SELECT 
       segment,
       first_order_date,
       month_number,
       cohort_size,
       MAX(CASE WHEN month_number = 0 THEN cohort_size END) OVER(PARTITION BY first_order_date) AS max_first_order,
       ROUND(
        cohort_size * 100.0 / 
        MAX(CASE WHEN month_number = 0 THEN cohort_size END) OVER(PARTITION BY first_order_date), 
        2
    ) AS retention_percentage,
    cohort_revenue,
    ROUND(
        cohort_revenue * 100.0 / 
        MAX(CASE WHEN month_number = 0 THEN cohort_revenue END) OVER(PARTITION BY first_order_date), 
        2
    ) AS revenue_retention_pct,
    unique_products_bought
FROM combined_activity
ORDER BY segment,first_order_date,month_number;

SELECT *
FROM vw_cohort_retention_all
LIMIT 10;
