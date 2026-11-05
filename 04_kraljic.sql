-- Family spend, vendor count and top vendor share, then quadrant
CREATE OR REPLACE TABLE kraljic AS
WITH fs AS (
    SELECT family, supplier_clean, SUM(total_price) AS vendor_spend, COUNT(*) AS lines
    FROM po_goods WHERE is_vendor AND family IS NOT NULL GROUP BY 1, 2
),
f AS (
    SELECT family, SUM(vendor_spend) AS spend, SUM(lines) AS lines, COUNT(*) AS suppliers,
           MAX(vendor_spend) / SUM(vendor_spend) AS top_supplier_share
    FROM fs GROUP BY 1 HAVING SUM(lines) >= 30
),
t AS (SELECT QUANTILE_CONT(spend, 0.75) AS spend_cut FROM f)
SELECT f.family, ROUND(f.spend / 1e6, 1) AS spend_m, f.suppliers,
       ROUND(f.top_supplier_share, 2) AS top_supplier_share,
       CASE WHEN f.spend >= t.spend_cut AND f.top_supplier_share >= 0.4 THEN 'Strategic'
            WHEN f.spend >= t.spend_cut THEN 'Leverage'
            WHEN f.top_supplier_share >= 0.4 THEN 'Bottleneck'
            ELSE 'Routine' END AS quadrant
FROM f CROSS JOIN t;

-- Quadrant summary
SELECT quadrant, COUNT(*) AS families, ROUND(SUM(spend_m), 0) AS spend_m,
       ROUND(100 * SUM(spend_m) / SUM(SUM(spend_m)) OVER (), 1) AS pct_of_spend
FROM kraljic GROUP BY 1 ORDER BY 3 DESC;

-- Largest families in each quadrant
SELECT quadrant, family, spend_m, suppliers, top_supplier_share
FROM kraljic
QUALIFY ROW_NUMBER() OVER (PARTITION BY quadrant ORDER BY spend_m DESC) <= 5
ORDER BY quadrant, spend_m DESC;