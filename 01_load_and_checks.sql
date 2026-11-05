-- Load the raw California purchase order file into DuckDB
.open C:/Users/ethan/Downloads/procurement-spend-analysis/procurement.duckdb

CREATE OR REPLACE TABLE po_raw AS
SELECT * FROM read_csv(
    'C:/Users/ethan/Downloads/procurement-spend-analysis/data/purchase-order-data-2012-2015-.csv',
    header = true,
    all_varchar = true
);

SHOW TABLES;

SELECT COUNT(*) AS rows, COUNT(DISTINCT "Purchase Order Number") AS distinct_pos FROM po_raw;
SELECT "Fiscal Year", COUNT(*) AS rows FROM po_raw GROUP BY 1 ORDER BY 1;
SELECT "Acquisition Type", COUNT(*) AS rows FROM po_raw GROUP BY 1 ORDER BY 2 DESC;