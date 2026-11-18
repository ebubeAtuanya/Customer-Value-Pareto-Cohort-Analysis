-- DATA CLEANING AND ETL LOGIC
-- FILTERED OUT THE CANCELLED ORDERS, POSTAGE, GIFT CARDS AND SO ON 
-- CHANGED CUSTOMERS ID THAT ARE ZEROS TO GUEST
-- CREATED A FACT AND DIMENSION TABLE FOR BETTER DATA MODELLING 
CREATE TABLE online_retail_clean (
    Invoice VARCHAR(20),
    StockCode VARCHAR(20),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate DATETIME,
    Price DECIMAL(10, 2),
    Customer_ID INT,
    Country VARCHAR(100)
);

ALTER TABLE online_retail_clean MODIFY COLUMN InvoiceDate DATE;

TRUNCATE TABLE online_retail_clean;

INSERT INTO online_retail_clean
-- CREATED A TEMP TABLE TO FILTER THE STOCKCODE THAT HAS DIFFERENT DESCRIPTION
-- LEFT JOINED THE DATASET WITH THE TEMP TABLE
WITH ProductUnique AS (
SELECT 
	 StockCode,
	 UPPER(TRIM(Description)) AS Description,
	 COUNT(*) AS row_occurrence,
	 ROW_NUMBER() OVER(PARTITION BY StockCode ORDER BY COUNT(*) DESC) AS row_num
FROM online_retail
WHERE Description IS NOT NULL AND TRIM(Description) <> ''
GROUP BY StockCode, UPPER(TRIM(Description))
)
SELECT  
		DISTINCT r.Invoice,
		r.StockCode,
	CASE WHEN 
        p.Description IS NULL OR TRIM(p.Description) = '' THEN 'UNKNOWN PRODUCTS'
		ELSE p.Description 
	END AS Description,
		r.Quantity,
		DATE(r.InvoiceDate),
		r.Price,
	CASE WHEN 
		r.Customer_ID IS NULL OR r.Customer_ID = 0 OR r.Customer_ID = '' THEN NULL 
		ELSE r.Customer_ID 
	END AS Customer_ID,
		r.Country
FROM online_retail r
LEFT JOIN ProductUnique p
	ON r.StockCode = p.StockCode
		AND P.row_num = 1
WHERE Invoice NOT LIKE 'C%'
		AND r.Quantity > 0
			AND r.Price > 0
		AND r.StockCode NOT REGEXP '^[a-zA-Z]';

-- CREATE PRODUCT DIMENSION TABLE
CREATE TABLE dim_products (
		ProductKey INT AUTO_INCREMENT PRIMARY KEY,
		StockCode VARCHAR(20), 
		Description VARCHAR(255)
);
INSERT INTO dim_products (StockCode, Description)
SELECT 
     DISTINCT StockCode,
	 Description 
FROM online_retail_clean;

TRUNCATE TABLE fact_sales;

CREATE TABLE fact_sales (
		Invoice VARCHAR (20),
		ProductKey INT,
		Customer_ID VARCHAR(50),
		Quantity INT,
		InvoiceDate DATE,
		Price DECIMAL(10,2),
		Revenue DECIMAL(10,2),
		Country VARCHAR(255),
		FOREIGN KEY (ProductKey) REFERENCES dim_products(ProductKey)
);

INSERT INTO fact_sales (Invoice, ProductKey, Customer_ID, Quantity, InvoiceDate, Price, Revenue, Country)
SELECT 
	  r.Invoice,
	  p.ProductKey,
	  COALESCE(r.Customer_ID, 'GUEST') AS Customer_ID,
	  r.Quantity,
	  r.InvoiceDate,
	  r.Price,
	  (r.Quantity * r.Price) AS Revenue,
	  r.Country
FROM online_retail_clean r
LEFT JOIN dim_products p
    ON r.StockCode = p.StockCode;