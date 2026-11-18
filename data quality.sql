-- IMPORT OF CSV DATASETS
CREATE TABLE online_retail (
    Invoice VARCHAR(20),
    StockCode VARCHAR(20),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate DATETIME,
    Price DECIMAL(10, 2),
    Customer_ID INT,
    Country VARCHAR(100)
);
SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE 'C:/Users/HomePC/Downloads/archive/online_retail_II.csv'
INTO TABLE online_retail
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

 -- RAW DATA DISCOVERY & INTEGRITY CHECKS (BEFORE CLEANING)
-- Objective: Understand table structures and catch initial bugs.
-- UNDERSTANDING THE DATA
DESCRIBE online_retail;

-- CHECK FOR DUPLICATES
-- DISCOVERY: THERE ARE DUPLICATES
SELECT 
	  Invoice,
	  StockCode,
	  Quantity, 
	  InvoiceDate,
	  Price, 
	  Customer_ID,
	  Country, 
	  COUNT(*) as Duplicate_values
FROM online_retail
GROUP BY Invoice, StockCode, Quantity, InvoiceDate, Price, Customer_ID,Country
HAVING COUNT(*) > 1;

-- CHECK FOR NULL VALUES IN CUSTOMERID AND BLANKS
SELECT  
        Customer_ID, 
        COUNT(*) AS missing_value
FROM online_retail
WHERE Customer_ID IS NULL 
 OR Customer_ID = '' 
   OR Customer_ID = 0
GROUP BY Customer_ID;

-- CHECK FOR BLANKS AND NULLS
-- DISCOVERY: DESCRIPTION HAS BLANKS
SELECT COUNT(CASE WHEN Description IS NULL THEN 1 END) AS Unknown_desc,
       COUNT(CASE WHEN TRIM(Description) = '' THEN 1 END) AS empty_desc,
       COUNT(CASE WHEN Country IS NULL OR TRIM(Country) = '' THEN 1 END) AS missing_values,
	   COUNT(CASE WHEN StockCode IS NULL OR StockCode = '' THEN 1 END) AS missing_stockcode
FROM online_retail;


-- CHECK FOR CANCELLED ORDER, PRICES  <= 0 AND QUANTITIES <=0
-- DISCOVERY: LOTS OF CANCELLED ORDERS, NEGATIVE PRICES AND QUANTITIES LESS THAN ZERO
SELECT SUM(CASE WHEN Invoice LIKE 'C%' THEN 1 ELSE 0 END) AS cancelled_order,
       SUM(CASE WHEN Price <= 0 THEN 1 ELSE 0 END) AS zero_price,
       SUM(CASE WHEN Quantity <=0  THEN 1 ELSE 0 END) negative_quantities
FROM online_retail;

-- CHECK FOR NON-PRODUCT STOCKCODES
-- DISCOVERY: FOUND LOTS OF THEM LIKE POSTAGE, GIFT, AMAZON AND SO ON
SELECT StockCode, Description, COUNT(*)
FROM online_retail
WHERE StockCode REGEXP '^[a-zA-Z]' 
GROUP BY StockCode, Description;

-- CHECK FOR DIFFERENT PRODUCT ON A UNIQUE STOCKCODE
-- DISCOVERY: FOUND SAME STOCKCODE WITH DIFFERENT DESCRIPTION
SELECT 
    StockCode, 
    UPPER(TRIM(Description)) AS Description, 
    COUNT(*) AS Row_Count,
    MIN(InvoiceDate) AS First_Seen,
    MAX(InvoiceDate) AS Last_Seen
FROM online_retail
WHERE Description IS NOT NULL AND Description != ''
GROUP BY StockCode, UPPER(TRIM(Description))
ORDER BY StockCode;

-- CHECK THE DURATION
-- DISCOVERY: FOR 2 YEARS, FROM 2009 DECEMBER TO 2011 DECEMBER 
SELECT 
	MIN(InvoiceDate)AS first_date, 
	MAX(InvoiceDate) AS last_date,
	TIMESTAMPDIFF(Year,MIN(InvoiceDate),MAX(InvoiceDate)) AS order_range_year
FROM online_retail;

-- CHECK FOR UNIQUE CUSTOMERS THAT BOUGHT FROM MORE THAN ONE COUNTRY
-- DISCOVERY: A FEW OF THEM DID
SELECT Customer_ID, COUNT(DISTINCT Country) AS country_count
FROM online_retail
WHERE Customer_ID IS NOT NULL
GROUP BY Customer_ID
HAVING COUNT(DISTINCT Country) > 1;


-- CHECK OUTLIERS IN QUANTITY
-- DISCOVERY: YES BUT NEED TO DO AN INTERGRITY TEST USING PERCENTILE TO BE SURE
SELECT MIN(Quantity) AS smallest_quantity, MAX(Quantity) AS largest_quantity
FROM online_retail;

-- CHECK WHETHER THE OUTLIERS ARE FROM CANCELLED ORDER OR GHOST CUSTOMER
-- DISCOVERY: NOT ALL
SELECT 
	 Invoice,
	 StockCode,
	 Description,
	 Quantity,
	 Price,
	 Customer_ID
FROM online_retail
WHERE Quantity < 0
ORDER BY Quantity ASC
LIMIT 5;

-- CHECK OUTLIERS IN PRICE
-- DISCOVERY: YES BUT NEED TO DO AN INTERGRITY TEST USING PERCENTILE TO BE SURE
SELECT 
     MIN(Price) AS lowest_price,
     MAX(Price) AS maximum_price
FROM online_retail;

-- CHECK WHETHER THE OUTLIERS ARE FROM CANCELLED ORDER OR GHOST CUSTOMER
-- DISCOVERY: NOT ALL
SELECT 
	 Invoice,
	 StockCode,
	 Description,
	 Quantity,
	 Price,
	 Customer_ID
FROM online_retail
WHERE Price <= 0
ORDER BY Price ASC
LIMIT 5;

SELECT DATABASE();


-- ACCESSING THE DATA
SELECT *
FROM online_retail
LIMIT 5;
