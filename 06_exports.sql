-- Export CSVs for Excel, Power BI and the forecast notebook
COPY (
    SELECT DATE_TRUNC('month', creation_date)::DATE AS month, COUNT(*) AS lines,
           COUNT(DISTINCT po_number) AS pos, ROUND(SUM(total_price), 2) AS spend
    FROM po_goods WHERE is_vendor
    GROUP BY 1 ORDER BY 1
) TO 'C:/Users/ethan/Downloads/data/monthly_goods.csv' (HEADER, DELIMITER ',');

COPY (SELECT * FROM kraljic ORDER BY spend_m DESC)
TO 'C:/Users/ethan/Downloads/data/kraljic.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT department, COUNT(*) AS lines, ROUND(SUM(total_price), 2) AS spend
    FROM po_goods WHERE is_vendor GROUP BY 1 ORDER BY 3 DESC
) TO 'C:/Users/ethan/Downloads/data/department_spend.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT segment, COUNT(*) AS lines, ROUND(SUM(total_price), 2) AS spend
    FROM po_goods WHERE segment IS NOT NULL AND is_vendor GROUP BY 1 ORDER BY 3 DESC
) TO 'C:/Users/ethan/Downloads/data/segment_spend.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT supplier_clean, COUNT(*) AS lines, COUNT(DISTINCT family) AS families, ROUND(SUM(total_price), 2) AS spend
    FROM po_goods WHERE is_vendor GROUP BY 1 ORDER BY 4 DESC LIMIT 100
) TO 'C:/Users/ethan/Downloads/data/top_vendors.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT family, COUNT(DISTINCT supplier_clean) AS suppliers, ROUND(SUM(total_price), 2) AS spend
    FROM po_goods WHERE family IS NOT NULL AND is_vendor GROUP BY 1 ORDER BY 3 DESC
) TO 'C:/Users/ethan/Downloads/data/family_suppliers.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT CASE
             WHEN acquisition_method IN ('Statewide Contract', 'CMAS', 'WSCA/Coop', 'Master Service Agreement',
                  'Master Purchase/Price Agreement', 'Software License Program', 'State Price Schedule') THEN 'Contract vehicle'
             WHEN acquisition_method IN ('Informal Competitive', 'Formal Competitive', 'NCB', 'LCB', 'SB/DVBE Option',
                  'Fair and Reasonable') THEN 'Competitive or small purchase'
             ELSE 'Other (emergency, exempt, programs)'
           END AS buying_route,
           COUNT(*) AS lines, ROUND(SUM(total_price), 2) AS spend
    FROM po_goods WHERE is_vendor GROUP BY 1 ORDER BY 3 DESC
) TO 'C:/Users/ethan/Downloads/data/buying_route.csv' (HEADER, DELIMITER ',');

COPY (
    SELECT item, COUNT(*) AS lines, ROUND(SUM(total_price), 2) AS spend, ROUND(SUM(excess_spend), 2) AS excess_spend
    FROM price_validated GROUP BY 1 ORDER BY 4 DESC
) TO 'C:/Users/ethan/Downloads/data/price_validated.csv' (HEADER, DELIMITER ',');