-- Spend by acquisition type
SELECT acquisition_type, COUNT(*) AS lines, ROUND(SUM(total_price) / 1e9, 2) AS spend_billions
FROM po_clean WHERE total_price > 0
GROUP BY 1 ORDER BY 3 DESC;

-- Goods spend by department
SELECT department, ROUND(SUM(total_price) / 1e6, 1) AS spend_m,
       ROUND(100 * SUM(total_price) / SUM(SUM(total_price)) OVER (), 1) AS pct_of_goods
FROM po_goods GROUP BY 1 ORDER BY 2 DESC LIMIT 15;

-- Goods spend by segment
SELECT segment, ROUND(SUM(total_price) / 1e6, 1) AS spend_m,
       ROUND(100 * SUM(total_price) / SUM(SUM(total_price)) OVER (), 1) AS pct_of_goods
FROM po_goods WHERE segment IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 15;

-- Supplier Pareto
WITH s AS (SELECT supplier_clean, SUM(total_price) AS spend FROM po_goods WHERE is_vendor GROUP BY 1)
SELECT supplier_clean, ROUND(spend / 1e6, 1) AS spend_m,
       ROUND(100 * spend / SUM(spend) OVER (), 1) AS pct,
       ROUND(100 * SUM(spend) OVER (ORDER BY spend DESC) / SUM(spend) OVER (), 1) AS cum_pct
FROM s ORDER BY spend DESC LIMIT 20;

-- Suppliers making up 80% of spend
WITH s AS (SELECT supplier_clean, SUM(total_price) AS spend FROM po_goods WHERE is_vendor GROUP BY 1),
c AS (SELECT SUM(spend) OVER (ORDER BY spend DESC) / SUM(spend) OVER () AS cum FROM s)
SELECT COUNT(*) FILTER (WHERE cum <= 0.8) + 1 AS suppliers_for_80pct, COUNT(*) AS total_suppliers FROM c;

-- Top 10, 50, 100 supplier share
WITH s AS (SELECT supplier_clean, SUM(total_price) AS spend FROM po_goods WHERE is_vendor GROUP BY 1),
r AS (SELECT spend, ROW_NUMBER() OVER (ORDER BY spend DESC) AS rn FROM s)
SELECT ROUND(100 * SUM(spend) FILTER (WHERE rn <= 10) / SUM(spend), 1) AS top10_pct,
       ROUND(100 * SUM(spend) FILTER (WHERE rn <= 50) / SUM(spend), 1) AS top50_pct,
       ROUND(100 * SUM(spend) FILTER (WHERE rn <= 100) / SUM(spend), 1) AS top100_pct
FROM r;

-- Supplier fragmentation by product family
SELECT family, COUNT(DISTINCT supplier_clean) AS suppliers, ROUND(SUM(total_price) / 1e6, 1) AS spend_m,
       ROUND(SUM(total_price) / COUNT(DISTINCT supplier_clean) / 1e3, 0) AS spend_per_supplier_k
FROM po_goods WHERE family IS NOT NULL AND is_vendor
GROUP BY 1 ORDER BY SUM(total_price) DESC LIMIT 15;

-- Buying route
SELECT CASE
         WHEN acquisition_method IN ('Statewide Contract', 'CMAS', 'WSCA/Coop', 'Master Service Agreement',
              'Master Purchase/Price Agreement', 'Software License Program', 'State Price Schedule') THEN 'Contract vehicle'
         WHEN acquisition_method IN ('Informal Competitive', 'Formal Competitive', 'NCB', 'LCB', 'SB/DVBE Option',
              'Fair and Reasonable') THEN 'Competitive or small purchase'
         ELSE 'Other (emergency, exempt, programs)'
       END AS buying_route,
       COUNT(*) AS lines, ROUND(SUM(total_price) / 1e6, 1) AS spend_m,
       ROUND(100 * SUM(total_price) / SUM(SUM(total_price)) OVER (), 1) AS pct_of_goods
FROM po_goods GROUP BY 1 ORDER BY 3 DESC;

-- DVBE supplier spend
SELECT COALESCE(supplier_qualifications LIKE '%DVBE%', false) AS dvbe_supplier,
       supplier_qualifications IS NOT NULL AS has_qualification_info,
       ROUND(SUM(total_price) / 1e6, 1) AS spend_m
FROM po_goods GROUP BY 1, 2 ORDER BY 3 DESC;