# GoOutside: BigQuery, Google Sheets and Looker Studio

Bootcamp project at WBS Coding School. The setup: GoOutside, a (fictional) outdoor and camping gear supplier, lost its only data analyst. What's left is a handful of CSV files and colleagues who don't know SQL. My job was to get the data into BigQuery, build Google Sheets for two people who need answers, and make a Looker Studio dashboard for everyone else.

The final step was a five-minute demo for the CEO. The point was to show the tools working, not to present an analysis.

**BigQuery** (tables and SQL views) → **Google Sheets** (Connected Sheets for Dustin and Sarah) → **Looker Studio** (dashboard)

## The two questions

**Dustin, Head of Retail Partnerships**, wants to know what the markets look like. Is a country dominated by a few big retailers, or split between lots of smaller ones? He has different targets for each:
- Big-player markets: +10% sales volume per retailer
- Competitive markets: +15% more retailers

**Sarah, Finance Manager**, thinks some order methods aren't worth the staff they need. She wants to see what each method brings in (revenue, profit, number of orders) and how that has changed over the years.

## The data

Four CSVs in `data/`:

| File | What's in it | Key |
|---|---|---|
| `GoOutside_daily_sales.csv` | One row per order line: retailer, product, order method, date, quantity, prices | Fact table |
| `GoOutside_retailers.csv` | Retailer name, type and country | `Retailer code` |
| `GoOutside_products.csv` | Product line, type, brand, unit cost | `Product number` |
| `GoOutside_methods.csv` | The 7 order methods (E-mail, Fax, Mail, Sales visit, Special, Telephone, Web) | `Order method code` |

It's a simple star schema. The sales table has 149,257 rows and links to 562 retailers in 21 countries, 274 products and 7 order methods.

One thing to know: the sales data runs from 12 January 2015 to **20 July 2018**. So 2018 is only half a year, and full-year totals make it look like sales dropped. When I compare years, I compare the same period (1 January to 20 July) every year.

How I calculate things:
- **Revenue** = Quantity × Unit sale price
- **Profit** = Quantity × (Unit sale price − Unit cost)
- **Orders**: there's no order ID, so I count order lines (rows) instead

## BigQuery

I uploaded the CSVs into a dataset called `GoOutsideDB` and let BigQuery detect the schema. Everything else reads from views, so revenue and profit are calculated in one place and the Sheets and the dashboard always show the same numbers.

| View | For | What it does |
|---|---|---|
| `v_dustin_markets` | Dustin | One row per country: retailers, revenue, top retailer's share, HHI, market type and target |
| `v_dustin_retailers` | Dustin | One row per retailer: rank, market share and cumulative share in its country |
| `v_sarah_methods` | Sarah | Order lines, units and revenue per order method |
| `v_sarah_yearly` | Sarah | Revenue and profit per year, plus the same-period numbers (to 20 July) |
| `v_sales_flat` | Everyone | All four tables joined, one row per order line, revenue and profit included |
| `v_sales_dashboard` | Looker Studio | Same as `v_sales_flat` but with column names without spaces (see below) |

### Big players or competitive?

To sort the markets I used the **Herfindahl-Hirschman Index (HHI)**, which is just the sum of squares of the retailers' market shares in a country. If one retailer has everything, you get 1. If n retailers are about the same size, you get about 1/n. I put the cut-off at 0.25, which is the usual threshold for a highly concentrated market. The top retailer's share is shown next to it, since that's easier to explain than an index.

## Google Sheets

Dustin and Sarah each have their own workbook, connected to the BigQuery views. The raw data sits in extract tabs that can be refreshed, and the tabs they actually use are built on top of those, so refreshing doesn't break the formatting or the charts.

**Dustin's workbook**
- *Markets*: every country with its market type and target, and a scatter plot of number of retailers vs. the top retailer's share. Concentrated markets end up top left, competitive ones bottom right.
- *Retailers by country*: pick a country from the dropdown and the table and chart show how that market is split up.

![Market overview](pictures/Scatter%20Plot%20with%20underlying%20data.png)
![Retailer shares for a selected country](pictures/Sheets%20Market%20Concentration%20with%20Graph.png)

**Sarah's workbook**
- Order methods (order lines, units, revenue) and revenue and profit per year, with a same-period column so 2018 isn't read as a drop.
- A pivot of profit by order method and year, with two charts: profit per channel over time, and each channel's share of profit per year.

![Profit by order method](pictures/Sales%20Channels%20Graphs.png)

### Links (view only)

- [Dustin's spreadsheet](https://docs.google.com/spreadsheets/d/1iEyil3vZxLo5VrGfw0Jf2y2grlsyGyT1BHkeAMXzf9Y/edit?usp=sharing)
- [Sarah's spreadsheet](https://docs.google.com/spreadsheets/d/1PMsOO5voaqGg9tz3FhTijQm0Zd0PSoxUaz-n6GsGnug/edit?usp=sharing)
- [Master sheet](https://docs.google.com/spreadsheets/d/1L2WF6qXb5oBfpOxDsXYS2Kjz3HGyzif5dU1MYRmHQH0/edit?usp=sharing) (revenue per country and year, built on `v_sales_flat`)

They're view only, so the dropdown in Dustin's sheet is stuck on Belgium. Use *File → Make a copy* to try it. The data is from the last refresh, and refreshing needs access to my BigQuery project.

## Looker Studio

One page for everyone else, built on `v_sales_dashboard`:

- **Scorecards** for revenue, profit, margin, active retailers and brands, each compared with the same period the year before. The default range is 1 January to 20 July 2018, so the comparison is fair (revenue +29.8%, profit +31.4%).
- **Revenue and profit per month** over the whole period
- **Revenue by country** (map), **top brands**, **revenue by sales channel** and **top products** with margin
- **Filters** for date, country, order method and product line. Clicking a country, brand or channel filters the whole page.

[Live dashboard](https://datastudio.google.com/reporting/9b00b853-8ee8-453f-8910-6c75755f3e5e) · [PDF version](dashboard/Go_Outside_Dashboard.pdf) (still works after the Sandbox tables are gone)

![Dashboard overview](pictures/Looker%20Overview%20Dashboard.png)

Clicking Germany on the map:

![Dashboard filtered on Germany](pictures/Looker%20Filtered%20by%20Country.png)

Clicking a sales channel. Sales visits grew 75% compared with the same period in 2017:

![Dashboard filtered on sales visits](pictures/Looker%20filtered%20by%20sales%20channel.png)

## What the data says

- **Markets:** 15 of the 21 markets are dominated by a few retailers. In Switzerland one retailer has 87% of sales. The six competitive markets include the biggest ones: the US (54 retailers, none above 15%), the UK and Germany.
- **Growth:** comparing 1 January to 20 July each year, profit grew 25%, 28% and 31%, from 58M in 2015 to 121M in 2018. The 2018 "drop" is just the missing months.
- **Order methods:** Web went from about 36% of profit in 2015 to about 88% in 2018. Telephone fell from 34% to 2%, E-mail from 22% to 2%. Fax never gets above 0.5%, Mail is almost gone (9 order lines in 2018), and Special has had no sales since 2017. Sales visit is the only other channel that grew, from 3% to 7%.

## Things I ran into

- **2018 isn't a full year.** My first yearly totals showed a big drop in 2018. Checking the last date in the data explained it, and that's why everything compares the same period each year.
- **Sheets extracts stop at 50,000 rows, without telling you.** Fine for the small views, but `v_sales_flat` has almost 150,000 rows, so an extract would just drop two thirds of the sales. For the full data I used pivot tables directly on the connection, which run in BigQuery over all rows.
- **Looker Studio doesn't like spaces in column names.** `COUNT_DISTINCT(Retailer name)` just gave "Invalid field name". Renaming the columns in `v_sales_flat` would have broken the pivots in the Sheets, so the dashboard got its own view with names like `retailer_name`.
- **The BigQuery Sandbox deletes tables after 60 days.** So the SQL is all here and the setup can be rebuilt (see below), and there's a PDF of the dashboard.

## Rebuilding it

1. Get the files: `git clone https://github.com/niklaslivchitz/gooutside-bigquery-sheets-looker.git`
2. Create a Google Cloud project and a BigQuery dataset called `GoOutsideDB`.
3. Upload the four CSVs from `data/` with schema auto-detect, named `GO_DailySales`, `GO_Retailers`, `GO_Products` and `GO_Methods`.
4. In `sql/Views.sql`, swap `divine-command-510108-k1` for your own project ID and run it.
5. In Google Sheets: *Data* → *Data connectors* → *Connect to BigQuery*, then pick the views.

`sql/Exploratory_queries.sql` has the queries I used to get to know the data, one for each question in the brief.

## Tools

BigQuery (SQL with joins, CTEs, window functions), Google Sheets (Connected Sheets, extracts, pivots, `FILTER`, dropdowns), Looker Studio
