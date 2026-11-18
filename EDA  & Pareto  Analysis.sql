SELECT * FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'fact_sales';
 -- EXPLORATORY DATA ANALYSIS
 
 -- CHECK MAX AND MIN QUANTITY FOR POSSIBLE OUTLIERS
SELECT 
     MIN(Quantity),
     MAX(Quantity)
FROM fact_sales;

-- CHECK THE 50_PERCENTILE
-- RESULT OBSERVED:50% of all items bought consists of 5units or below and other 50% consists of 5 units or more
SELECT MIN(Quantity) AS percentile_50
FROM(
SELECT 
      Quantity,
      PERCENT_RANK() OVER(ORDER BY Quantity) AS percentile_rank
FROM fact_sales) AS P
WHERE percentile_rank >= 0.50;

-- CHECK MAX AND MIN PRICE FOR POSSIBLE OUTLIERS
SELECT 
     MIN(Price),
     MAX(Price)
FROM fact_sales;

-- CHECK THE 99_PERCENTILE
-- RESULT OBSERVED: 99% of items are priced under 16.98
-- REASON FOR INVESTIGATION: The maximum price was 1,157.15
-- CONCLUSION: Prices above 16.98 are rare outliers
-- ACTION TAKEN: Standard AVG(Price) was rejected. Weighted Average Price was selected for the final report
SELECT 
     MIN(Price) AS percent_99
FROM (
    SELECT 
        Price,
        PERCENT_RANK() OVER (ORDER BY Price) AS p_rank
    FROM fact_sales
) AS ranked_data
WHERE p_rank >= 0.99;

-- MEDIAN ORDER VALUE
-- DISCOVERY: 50% OF AL ORDERS ARE 301.24 OR LESS
WITH invoice_group AS(
SELECT 
      Invoice,
	  SUM(Quantity * Price) AS order_total
FROM fact_sales
GROUP BY Invoice),

order_rank AS (
SELECT 
      order_total,
      PERCENT_RANK() OVER(ORDER BY order_total) AS p_rankk
FROM invoice_group
)
SELECT ROUND(MIN(order_total),2) AS median_order_value
FROM order_rank
WHERE p_rankk >= 0.50;


-- CHECK FOR TOP 10% REVENUE BY PERCENTAGE
-- DISCOVERY: THE TOP 10% GENERATE 63.89% REVENUE
--  AND 20% GENERATE 77.18% THAT IS 20% OF CUSTOMERS GENERATE MORE THAN HALF OF REVENUE
CREATE OR REPLACE VIEW vw_pateo_analysis AS
WITH customer_revenue AS(
SELECT 
       Customer_ID,
       SUM(Quantity * Price) AS line_revenue
FROM fact_sales
WHERE Customer_ID != 'GUEST'
GROUP BY Customer_ID
),

customer_decile AS (
SELECT 
      Customer_ID,
      line_revenue,
      NTILE(10) OVER(ORDER BY line_revenue DESC) AS spend_decile
FROM customer_revenue
)

SELECT 
     spend_decile * 10 AS top_customers_pct,
     SUM(line_revenue) AS total_revenue,
     COUNT(DISTINCT Customer_ID) AS customers_num,
     ROUND(SUM(line_revenue) * 100.0 / SUM(SUM(line_revenue)) OVER (), 2) AS revenue_percentage,
     ROUND(SUM(SUM(line_revenue)) OVER(ORDER BY spend_decile) * 100.0 / SUM(SUM(line_revenue)) OVER (), 2) AS cummulative_revenue_pct
FROM customer_decile
GROUP BY spend_decile;

SELECT * FROM vw_pateo_analysis;

-- PURCHASE FREQUENCY, AVERAGE ORDER VALUE, WEIGHTED AVERAGE PRICE AND UNIT PER TRANSACTION
-- OF THE TOP 20% AND BOTTOM  80%
-- DISCOVERY: THE TOP 20% AND BOTTOM 80% WEIGHTED AVERAGE PRICE IS IN THE SAME RANGE(1.63 AND 1.62)
-- THE UPT FOR TOP 20% IS 161.54 AND BOTTOM 80% IS 372.86 SO THE TOP 20% HAVE LARGER BASKET SIZE PER 
-- TRANSATION
WITH purchase_frequency AS (
    SELECT 
           Customer_ID,
           SUM(Revenue) AS total_revenue,
           SUM(Quantity) AS quantity_sum,
           COUNT(DISTINCT Invoice) AS invoice_count
    FROM fact_sales
    WHERE Customer_ID != 'GUEST'
    GROUP BY Customer_ID
    ),
    purchase_decile AS (
    SELECT 
           invoice_count,
           Customer_ID,
           total_revenue,
           quantity_sum,
           CASE WHEN NTILE(5) OVER(ORDER BY total_revenue DESC) = 1 THEN 'TOP 20%'
           ELSE 'BOTTOM 80%' END AS decile
    FROM purchase_frequency)
    
    SELECT  decile,
           COUNT(DISTINCT Customer_ID) AS customer_count,
           ROUND(SUM(total_revenue)/ SUM(Invoice_count),2) AS  AOV,
		   ROUND(SUM(quantity_sum)/ SUM(Invoice_count),2) AS UPT,
           ROUND(SUM(total_revenue) / SUM(quantity_sum), 2) AS weighted_avg_price,
           ROUND(SUM( Invoice_count) /COUNT(DISTINCT Customer_ID),2) AS purchase_frequencys
	FROM purchase_decile
	GROUP BY decile;

--  GEOGRAPHIC PERFORMANCE REPORT
SELECT 
	   Country,
	   COUNT(DISTINCT Customer_ID) AS Total_customers,
       SUM(Quantity * Price) AS total_revenue,
       SUM(Quantity) AS total_items
FROM fact_sales
GROUP BY Country;

-- HIGH-VALUE CUSTOMERS (EXCLUDING GUESTS)
SELECT 
       Customer_ID,
       SUM(Quantity * Price) AS total_revenue
FROM fact_sales
WHERE Customer_ID != 'GUEST'
GROUP BY Customer_ID
ORDER BY total_revenue DESC;

-- REVENUE GENERATING PRODUCTS
SELECT 
       f.ProductKey,
       p.Description,
       SUM(f.Quantity * f.Price) AS total_revenue
FROM fact_sales f
LEFT JOIN dim_products p
		ON f.ProductKey = p.ProductKey
GROUP BY f.ProductKey,
         p.Description
ORDER BY total_revenue DESC
LIMIT 5;

-- KEY BUSINESS METRIC REPORT
SELECT 
       'Total Customers' AS fact_name, 
		COUNT(DISTINCT Customer_ID) AS fact_value FROM fact_sales
	UNION ALL	
SELECT 
        'Total Order' AS fact_name,
		COUNT( DISTINCT Invoice) AS fact_value
FROM fact_sales
	UNION ALL
SELECT 
        'Order Range' AS fact_name,
		TIMESTAMPDIFF(YEAR, MIN(InvoiceDate),MAX(InvoiceDate)) AS fact_value
FROM fact_sales
	UNION ALL
SELECT 
        'Total Revenue(Gross)' AS fact_name,
		SUM(Price * Quantity) AS fact_value
FROM fact_sales
	UNION ALL
SELECT 
	    'Total Items(Sold)' AS fact_name,
		SUM(Quantity) AS fact_value
FROM fact_sales
	UNION ALL
SELECT 
        'Unique Products(Sold)' AS fact_name, 
		COUNT(DISTINCT ProductKey) AS fact_value FROM dim_products
	UNION ALL
SELECT 
        'Products Sold in 2009',
		SUM(Quantity)
FROM fact_sales 
WHERE YEAR(InvoiceDate) = 2009
	UNION ALL
SELECT 
        'Products Sold in 2010',
		SUM(Quantity)
FROM fact_sales 
WHERE YEAR(InvoiceDate) = 2010
	UNION ALL
SELECT 
        'Products Sold in 2011',
		SUM(Quantity)
FROM fact_sales 
WHERE YEAR(InvoiceDate) = 2011;
 
-- SEGMENTED THE CUSTOMERS BY TOP 20% AND 80%
-- SLICER FOR THE DASHBOARD
CREATE OR REPLACE VIEW vw_slicer AS
WITH slicer AS (
SELECT 
      Customer_ID,
      SUM(Revenue) AS Total_revenue,
      CASE WHEN NTILE(5) OVER(ORDER BY SUM(Revenue) DESC) = 1 THEN 'TOP 20%'
      ELSE 'BOTTOM 80%' END AS CustomerTier
FROM fact_sales
WHERE Customer_ID != 'GUEST'
GROUP BY Customer_ID
)
SELECT 
      Customer_ID,
      CustomerTier
FROM slicer
UNION ALL
SELECT 
    'GUEST' AS Customer_ID,
    'Guest Customers' AS CustomerTier;

SELECT * FROM vw_slicer LIMIT 10;