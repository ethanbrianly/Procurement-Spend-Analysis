-- Clean the raw orders and build the goods table

-- Parse prices, which come as text like '$1,118.60' with credits as '($7.00)'
CREATE OR REPLACE MACRO parse_money(x) AS
    TRY_CAST(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(x), '^\((.*)\)$', '-\1'), '[$,\s]', '', 'g') AS DOUBLE);

-- Standardize supplier names
CREATE OR REPLACE MACRO norm_name(x) AS
    TRIM(REGEXP_REPLACE(
        REGEXP_REPLACE(
            REGEXP_REPLACE(UPPER(x), '[^A-Z0-9 ]', ' ', 'g'),
            '\b(INC|LLC|CORP|CORPORATION|CO|COMPANY|LTD|LP|THE)\b', ' ', 'g'),
        '\s+', ' ', 'g'));

CREATE OR REPLACE TABLE po_clean AS
SELECT
    TRY_STRPTIME("Creation Date", '%m/%d/%Y')::DATE AS creation_date,
    "Fiscal Year" AS fiscal_year,
    "Purchase Order Number" AS po_number,
    "Acquisition Type" AS acquisition_type,
    "Acquisition Method" AS acquisition_method,
    "Department Name" AS department,
    "Supplier Code" AS supplier_code,
    "Supplier Name" AS supplier_name,
    norm_name("Supplier Name") AS supplier_clean,
    "Supplier Qualifications" AS supplier_qualifications,
    "Item Name" AS item_name,
    "Item Description" AS item_description,
    TRY_CAST(REPLACE("Quantity", ',', '') AS DOUBLE) AS quantity,
    parse_money("Unit Price") AS unit_price,
    parse_money("Total Price") AS total_price,
    "Normalized UNSPSC" AS unspsc,
    "Commodity Title" AS commodity,
    "Class Title" AS class_title,
    "Family Title" AS family,
    "Segment Title" AS segment,
    ("LPA Number" IS NOT NULL) AS has_lpa
FROM (SELECT DISTINCT * FROM po_raw);

-- Merge supplier name variants
UPDATE po_clean SET supplier_clean = 'PRISON INDUSTRY AUTHORITY' WHERE supplier_clean = 'PIA';
UPDATE po_clean SET supplier_clean = 'WESTERN BLUE'
WHERE supplier_clean LIKE 'WESTERN BLUE%' OR supplier_clean LIKE 'NWN CORPORTATION%';

-- Flag vendors versus state entities and placeholders
ALTER TABLE po_clean ADD COLUMN is_vendor BOOLEAN;
UPDATE po_clean SET is_vendor = NOT (
    REGEXP_MATCHES(supplier_clean, '^(CALIFORNIA )?DEPARTMENT OF|^COUNTY OF|^REGENTS|COUNTY OFFICE OF EDUCATION|SUPERINTENDENT OF SCHOOLS|^PRISON INDUSTRY AUTHORITY|PROBATION')
    OR supplier_clean = 'UNKNOWN');

-- Goods and IT goods with positive prices and quantities
CREATE OR REPLACE TABLE po_goods AS
SELECT * FROM po_clean
WHERE acquisition_type IN ('NON-IT Goods', 'IT Goods')
  AND total_price > 0 AND unit_price > 0 AND quantity > 0;

SELECT COUNT(*) AS po_clean_rows FROM po_clean;
SELECT COUNT(*) AS goods_rows, ROUND(SUM(total_price) / 1e9, 2) AS goods_spend_billions FROM po_goods;
SELECT COUNT(*) FILTER (WHERE creation_date IS NULL) AS null_dates,
       COUNT(*) FILTER (WHERE total_price IS NULL) AS null_prices,
       COUNT(*) FILTER (WHERE total_price < 0) AS credits
FROM po_clean;