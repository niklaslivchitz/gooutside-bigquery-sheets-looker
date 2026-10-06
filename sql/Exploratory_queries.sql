/*
GoOutside: exploratory queries
--------------------------------------------------------------------------
My first look at the data, one query per question in the brief.
Highlight a query in the BigQuery editor and click Run to run just that
one. Change the project ID to your own.
*/


-- Q1  Data relationships
-- Sales is the fact table, the other three are lookup tables. If the row
-- count equals the number of distinct codes, the code is unique, so each
-- lookup table links many-to-one to sales.
SELECT 'retailers' AS lookup_table, COUNT(*) AS n_rows, COUNT(DISTINCT `Retailer code`) AS n_keys
FROM `divine-command-510108-k1.GoOutsideDB.GO_Retailers`
UNION ALL
SELECT 'products', COUNT(*), COUNT(DISTINCT `Product number`)
FROM `divine-command-510108-k1.GoOutsideDB.GO_Products`
UNION ALL
SELECT 'methods', COUNT(*), COUNT(DISTINCT `Order method code`)
FROM `divine-command-510108-k1.GoOutsideDB.GO_Methods`;


-- Q2  Temporal scope
SELECT MIN(Date) AS first_day, MAX(Date) AS last_day
FROM `divine-command-510108-k1.GoOutsideDB.GO_DailySales`;


-- Q3  Retailer landscape: number of retailers per country
SELECT Country, COUNT(*) AS retailers
FROM `divine-command-510108-k1.GoOutsideDB.GO_Retailers`
GROUP BY Country
ORDER BY retailers DESC;


-- Q4  Product popularity: top 3 product types by revenue in each country
WITH country_type AS (
  SELECT Country, `Product type`,
         SUM(Quantity * `Unit sale price`) AS revenue
  FROM `divine-command-510108-k1.GoOutsideDB.GO_DailySales`
  JOIN `divine-command-510108-k1.GoOutsideDB.GO_Retailers` USING (`Retailer code`)
  JOIN `divine-command-510108-k1.GoOutsideDB.GO_Products` USING (`Product number`)
  GROUP BY Country, `Product type`
)
SELECT *
FROM country_type
WHERE TRUE   -- BigQuery needs a WHERE (or GROUP BY / HAVING) to use QUALIFY
QUALIFY RANK() OVER (PARTITION BY Country ORDER BY revenue DESC) <= 3
ORDER BY Country, revenue DESC;


-- Q5  Sales performance: revenue and profit per year
-- Careful: 2018 stops on 20 July. v_sarah_yearly has the same-period comparison.
SELECT EXTRACT(YEAR FROM sales.Date) AS year,
       SUM(sales.Quantity * sales.`Unit sale price`) AS revenue,
       SUM(sales.Quantity * (sales.`Unit sale price` - products.`Unit cost`)) AS profit
FROM `divine-command-510108-k1.GoOutsideDB.GO_DailySales` AS sales
JOIN `divine-command-510108-k1.GoOutsideDB.GO_Products` AS products USING (`Product number`)
GROUP BY year
ORDER BY year;


-- Q6  Sales channels: activity per order method
SELECT `Order method type` AS method,
       COUNT(*) AS order_lines,
       SUM(Quantity) AS units_sold,
       SUM(Quantity * `Unit sale price`) AS revenue
FROM `divine-command-510108-k1.GoOutsideDB.GO_DailySales`
JOIN `divine-command-510108-k1.GoOutsideDB.GO_Methods` USING (`Order method code`)
GROUP BY method
ORDER BY revenue DESC;


-- Q7a  Sales drivers: product types
SELECT `Product type`,
       SUM(Quantity) AS units_sold,
       SUM(Quantity * `Unit sale price`) AS revenue
FROM `divine-command-510108-k1.GoOutsideDB.GO_DailySales`
JOIN `divine-command-510108-k1.GoOutsideDB.GO_Products` USING (`Product number`)
GROUP BY `Product type`
ORDER BY revenue DESC;


-- Q7b  Sales drivers: brands
SELECT `Product brand`,
       SUM(Quantity) AS units_sold,
       SUM(Quantity * `Unit sale price`) AS revenue
FROM `divine-command-510108-k1.GoOutsideDB.GO_DailySales`
JOIN `divine-command-510108-k1.GoOutsideDB.GO_Products` USING (`Product number`)
GROUP BY `Product brand`
ORDER BY revenue DESC;
