-- Vendor goods lines with a category code and item name
CREATE OR REPLACE TABLE price_base AS
SELECT unspsc, UPPER(TRIM(item_name)) AS item_key, department, supplier_clean, quantity, unit_price, total_price
FROM po_goods
WHERE is_vendor AND unspsc IS NOT NULL AND item_name IS NOT NULL;

-- Comparable item groups with enough lines, enough vendors and a consistent price range
CREATE OR REPLACE TABLE price_groups AS
SELECT unspsc, item_key, COUNT(*) AS lines, COUNT(DISTINCT supplier_clean) AS suppliers,
       COUNT(DISTINCT department) AS departments, SUM(total_price) AS spend,
       MEDIAN(unit_price) AS median_price
FROM price_base
GROUP BY 1, 2
HAVING COUNT(*) >= 10 AND COUNT(DISTINCT supplier_clean) >= 3
   AND QUANTILE_CONT(unit_price, 0.75) <= 3 * QUANTILE_CONT(unit_price, 0.25);

-- Excess spend: lines priced above the group median but within 3x of it
CREATE OR REPLACE TABLE price_savings AS
SELECT b.unspsc, b.item_key, b.department, b.supplier_clean, b.quantity, b.unit_price, g.median_price,
       CASE WHEN b.unit_price > g.median_price AND b.unit_price <= 3 * g.median_price
            THEN (b.unit_price - g.median_price) * b.quantity ELSE 0 END AS excess_spend
FROM price_base b JOIN price_groups g USING (unspsc, item_key);

-- Summary of the automated estimate
SELECT (SELECT COUNT(*) FROM price_groups) AS item_groups,
       ROUND((SELECT SUM(spend) FROM price_groups) / 1e6, 1) AS covered_spend_m,
       ROUND(SUM(excess_spend) / 1e6, 1) AS excess_spend_m,
       ROUND(100 * SUM(excess_spend) / (SELECT SUM(spend) FROM price_groups), 1) AS excess_pct
FROM price_savings;

-- Largest item groups by excess spend
SELECT s.item_key, g.suppliers, g.lines, ROUND(g.median_price, 2) AS median_price,
       ROUND(SUM(s.excess_spend) / 1e3, 0) AS excess_k
FROM price_savings s JOIN price_groups g USING (unspsc, item_key)
GROUP BY s.item_key, g.suppliers, g.lines, g.median_price
ORDER BY SUM(s.excess_spend) DESC LIMIT 15;

-- Strict version: same category, item name and description
CREATE OR REPLACE TABLE price_strict AS
WITH b AS (
    SELECT unspsc, UPPER(TRIM(item_name)) || ' | ' || UPPER(TRIM(item_description)) AS item_key,
           supplier_clean, quantity, unit_price, total_price
    FROM po_goods
    WHERE is_vendor AND unspsc IS NOT NULL AND item_name IS NOT NULL AND item_description IS NOT NULL
),
g AS (
    SELECT unspsc, item_key, COUNT(*) AS lines, COUNT(DISTINCT supplier_clean) AS suppliers,
           SUM(total_price) AS spend, MEDIAN(unit_price) AS median_price
    FROM b GROUP BY 1, 2
    HAVING COUNT(*) >= 10 AND COUNT(DISTINCT supplier_clean) >= 3
       AND QUANTILE_CONT(unit_price, 0.75) <= 3 * QUANTILE_CONT(unit_price, 0.25)
)
SELECT g.unspsc, g.item_key, g.lines, g.suppliers, g.spend, g.median_price,
       SUM(CASE WHEN b.unit_price > g.median_price AND b.unit_price <= 3 * g.median_price
                THEN (b.unit_price - g.median_price) * b.quantity ELSE 0 END) AS excess
FROM g JOIN b USING (unspsc, item_key)
GROUP BY g.unspsc, g.item_key, g.lines, g.suppliers, g.spend, g.median_price;

-- Summary of the strict estimate
SELECT COUNT(*) AS item_groups, ROUND(SUM(spend) / 1e6, 1) AS covered_spend_m,
       ROUND(SUM(excess) / 1e6, 1) AS excess_spend_m, ROUND(100 * SUM(excess) / SUM(spend), 1) AS excess_pct
FROM price_strict;

-- Commodity-like item groups with per-unit prices
SELECT g.item_key, g.suppliers, g.lines, ROUND(g.median_price, 2) AS median_price,
       ROUND(g.spend / 1e3, 0) AS spend_k, ROUND(SUM(s.excess_spend) / 1e3, 0) AS excess_k
FROM price_groups g JOIN price_savings s USING (unspsc, item_key)
WHERE g.median_price BETWEEN 0.5 AND 200 AND g.lines >= 20
GROUP BY g.item_key, g.suppliers, g.lines, g.median_price, g.spend
ORDER BY SUM(s.excess_spend) DESC LIMIT 25;

-- Validated commodity items: excess spend using the median within each fiscal year
CREATE OR REPLACE TABLE price_validated AS
WITH items AS (
    SELECT * FROM po_goods
    WHERE is_vendor AND UPPER(TRIM(item_name)) IN ('JET A FUEL', 'SAND, DEICING', 'MULCH',
          'FUEL,GASOLINE,UNLEADED', 'FUEL,DIESEL #2,CARB,ULTRA LOW SULFUR')
),
m AS (
    SELECT UPPER(TRIM(item_name)) AS item, fiscal_year, MEDIAN(unit_price) AS median_price
    FROM items GROUP BY 1, 2
)
SELECT UPPER(TRIM(i.item_name)) AS item, i.fiscal_year, i.supplier_clean, i.quantity, i.unit_price,
       i.total_price, m.median_price,
       CASE WHEN i.unit_price > m.median_price AND i.unit_price <= 3 * m.median_price
            THEN (i.unit_price - m.median_price) * i.quantity ELSE 0 END AS excess_spend
FROM items i JOIN m ON UPPER(TRIM(i.item_name)) = m.item AND i.fiscal_year = m.fiscal_year;

-- Summary of validated items with a total row
SELECT COALESCE(item, 'TOTAL') AS item, COUNT(*) AS lines, ROUND(SUM(total_price) / 1e3, 0) AS spend_k,
       ROUND(SUM(excess_spend) / 1e3, 0) AS excess_k,
       ROUND(100 * SUM(excess_spend) / SUM(total_price), 1) AS excess_pct
FROM price_validated GROUP BY ROLLUP(item) ORDER BY excess_k DESC;