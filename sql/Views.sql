/*
GoOutside: BigQuery views
--------------------------------------------------------------------------
The six views behind the Sheets and the Looker Studio dashboard.


To rebuild: change the project ID divine-command-510108-k1 to your own
and run the whole file once.

How I calculate things:
  revenue = Quantity * Unit sale price
  profit  = Quantity * (Unit sale price - Unit cost)
*/


/* Dustin 1: one row per country.
   HHI = sum of squares of the retailers' market shares in a country.
   0.25 or more = big-player market, below that = competitive. */

CREATE OR REPLACE VIEW `divine-command-510108-k1.GoOutsideDB.v_dustin_markets` AS
WITH retailer_rev AS (
  SELECT Country, `Retailer code`,
         SUM(Quantity) AS volume,
         SUM(Quantity * `Unit sale price`) AS revenue
  FROM `divine-command-510108-k1.GoOutsideDB.GO_DailySales`
  JOIN `divine-command-510108-k1.GoOutsideDB.GO_Retailers` USING (`Retailer code`)
  -- WHERE EXTRACT(YEAR FROM Date) = 2017   -- optional: just one year
  GROUP BY Country, `Retailer code`
),
shares AS (
  SELECT *, revenue / SUM(revenue) OVER (PARTITION BY Country) AS share
  FROM retailer_rev
),
markets AS (
  SELECT Country,
         COUNT(*) AS retailers,
         SUM(volume) AS volume,
         SUM(revenue) AS revenue,
         MAX(share) AS top_share,
         SUM(share * share) AS hhi
  FROM shares
  GROUP BY Country
)
SELECT
  Country,
  IF(hhi >= 0.25, 'Big players', 'Competitive') AS `Market type`,
  IF(hhi >= 0.25,
     CONCAT('+10% volume per retailer: ',
            FORMAT("%'d", CAST(ROUND(volume / retailers * 1.1) AS INT64)), ' units'),
     CONCAT('+15% retailers: ',
            CAST(CAST(CEIL(retailers * 1.15) AS INT64) AS STRING), ' retailers')
  ) AS Target,
  retailers AS Retailers,
  ROUND(revenue, 0) AS Revenue,
  ROUND(top_share, 3) AS `Top retailer share`,
  ROUND(hhi, 3) AS HHI
FROM markets
ORDER BY `Market type`, Revenue DESC;


/* Dustin 2: one row per retailer, with its rank, market share and
   cumulative share in its country. */

CREATE OR REPLACE VIEW `divine-command-510108-k1.GoOutsideDB.v_dustin_retailers` AS
WITH retailer_rev AS (
  SELECT Country, `Retailer code`, `Retailer name`,
         SUM(Quantity) AS volume,
         SUM(Quantity * `Unit sale price`) AS revenue
  FROM `divine-command-510108-k1.GoOutsideDB.GO_DailySales`
  JOIN `divine-command-510108-k1.GoOutsideDB.GO_Retailers` USING (`Retailer code`)
  -- WHERE EXTRACT(YEAR FROM Date) = 2017   -- keep in sync with Dustin 1
  GROUP BY Country, `Retailer code`, `Retailer name`
),
shares AS (
  SELECT *,
         revenue / SUM(revenue) OVER (PARTITION BY Country) AS share
  FROM retailer_rev
)
SELECT
  Country,
  RANK() OVER (PARTITION BY Country ORDER BY revenue DESC) AS Rank,
  `Retailer name` AS Retailer,
  volume AS Volume,
  ROUND(revenue, 0) AS Revenue,
  ROUND(share, 3) AS `Market share`,
  ROUND(SUM(share) OVER (PARTITION BY Country ORDER BY revenue DESC), 3) AS `Cumulative share`
FROM shares
ORDER BY Country, Rank;


/* Sarah 1: what each order method brings in.
   There's no order ID in the data, so I count rows (order lines). */

CREATE OR REPLACE VIEW `divine-command-510108-k1.GoOutsideDB.v_sarah_methods` AS
SELECT `Order method type` AS method,
       COUNT(*) AS order_lines,
       SUM(Quantity) AS units_sold,
       SUM(Quantity * `Unit sale price`) AS revenue
FROM `divine-command-510108-k1.GoOutsideDB.GO_DailySales`
JOIN `divine-command-510108-k1.GoOutsideDB.GO_Methods` USING (`Order method code`)
GROUP BY method;


/* Sarah 2: revenue and profit per year.
   The data stops on 20 July 2018, so 2018 is only half a year. The
   *_same_period columns only count sales up to the same day of the year,
   every year. Use those to compare years, not the full-year totals. */

CREATE OR REPLACE VIEW `divine-command-510108-k1.GoOutsideDB.v_sarah_yearly` AS
WITH cutoff AS (
  SELECT EXTRACT(DAYOFYEAR FROM MAX(Date)) AS last_day
  FROM `divine-command-510108-k1.GoOutsideDB.GO_DailySales`
)
SELECT EXTRACT(YEAR FROM sales.Date) AS year,
       MIN(sales.Date) AS first_sale,
       MAX(sales.Date) AS last_sale,
       SUM(sales.Quantity * sales.`Unit sale price`) AS revenue,
       SUM(sales.Quantity * (sales.`Unit sale price` - products.`Unit cost`)) AS profit,
       SUM(IF(EXTRACT(DAYOFYEAR FROM sales.Date) <= cutoff.last_day,
              sales.Quantity * sales.`Unit sale price`, 0)) AS revenue_same_period,
       SUM(IF(EXTRACT(DAYOFYEAR FROM sales.Date) <= cutoff.last_day,
              sales.Quantity * (sales.`Unit sale price` - products.`Unit cost`), 0)) AS profit_same_period
FROM `divine-command-510108-k1.GoOutsideDB.GO_DailySales` AS sales
JOIN `divine-command-510108-k1.GoOutsideDB.GO_Products` AS products USING (`Product number`)
CROSS JOIN cutoff
GROUP BY year;


/* Flat view: all four tables joined, one row per order line, with
   revenue and profit already calculated. Used by the Sheets pivots and Looker */

CREATE OR REPLACE VIEW `divine-command-510108-k1.GoOutsideDB.v_sales_flat` AS
SELECT
  s.Date,
  EXTRACT(YEAR FROM s.Date) AS year,
  r.Country,
  r.`Retailer name`,
  r.Type AS `Retailer type`,
  p.`Product line`,
  p.`Product type`,
  p.`Product brand`,
  p.Product,
  m.`Order method type`,
  s.Quantity,
  s.Quantity * s.`Unit sale price` AS revenue,
  s.Quantity * (s.`Unit sale price` - p.`Unit cost`) AS profit
FROM `divine-command-510108-k1.GoOutsideDB.GO_DailySales` AS s
JOIN `divine-command-510108-k1.GoOutsideDB.GO_Retailers` AS r USING (`Retailer code`)
JOIN `divine-command-510108-k1.GoOutsideDB.GO_Products` AS p USING (`Product number`)
JOIN `divine-command-510108-k1.GoOutsideDB.GO_Methods` AS m USING (`Order method code`);


/* Same as v_sales_flat, but for Looker Studio.
   Looker Studio can't handle column names with spaces in calculated
   fields (COUNT_DISTINCT(Retailer name) gives "Invalid field name"), so
   everything here is renamed to snake_case. I didn't rename the columns
   in v_sales_flat because the Sheets pivots use the old names. */

CREATE OR REPLACE VIEW `divine-command-510108-k1.GoOutsideDB.v_sales_dashboard` AS
SELECT
  s.Date AS date,
  EXTRACT(YEAR FROM s.Date) AS year,
  r.Country AS country,
  r.`Retailer name` AS retailer_name,
  r.Type AS retailer_type,
  p.`Product line` AS product_line,
  p.`Product type` AS product_type,
  p.`Product brand` AS product_brand,
  p.Product AS product,
  m.`Order method type` AS order_method,
  s.Quantity AS quantity,
  s.Quantity * s.`Unit sale price` AS revenue,
  s.Quantity * (s.`Unit sale price` - p.`Unit cost`) AS profit
FROM `divine-command-510108-k1.GoOutsideDB.GO_DailySales` AS s
JOIN `divine-command-510108-k1.GoOutsideDB.GO_Retailers` AS r USING (`Retailer code`)
JOIN `divine-command-510108-k1.GoOutsideDB.GO_Products` AS p USING (`Product number`)
JOIN `divine-command-510108-k1.GoOutsideDB.GO_Methods` AS m USING (`Order method code`);
