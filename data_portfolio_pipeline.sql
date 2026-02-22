/* Creating Schemas
- Retail Operations Data Warehouse Set Up
- Learning Notes:
Schemas = layers.
   raw: landing zone (no business rules)
   staging: cleaned + typed + validated
   core: star schema (dims/facts)
   marts: business-ready views for reporting */

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS marts;

/* Creating RAW tables 
- CSVs will be creating matching the column headers for all tables
- Learning Notes:
RAW tables match CSV headers 1:1.
   Design choice: store most fields as TEXT in raw to avoid load failures.
   Data typing + validation happens in staging. */

CREATE TABLE IF NOT EXISTS raw.products (
  product_id     TEXT,
  product_name   TEXT,
  category       TEXT,
  sub_category   TEXT,
  unit_cost      TEXT,
  unit_price     TEXT,
  supplier_id    TEXT
);

CREATE TABLE IF NOT EXISTS raw.stores (
  store_id       TEXT,
  store_name     TEXT,
  region         TEXT,
  country        TEXT
);

CREATE TABLE IF NOT EXISTS raw.orders (
  order_id       TEXT,
  order_date     TEXT,
  store_id       TEXT,
  customer_id    TEXT,
  product_id     TEXT,
  quantity       TEXT,
  unit_price     TEXT,
  discount_pct   TEXT
);

CREATE TABLE IF NOT EXISTS raw.inventory_snapshots (
  snapshot_date  TEXT,
  store_id       TEXT,
  product_id     TEXT,
  on_hand_qty    TEXT
);

CREATE TABLE IF NOT EXISTS raw.suppliers (
  supplier_id           TEXT,
  supplier_name         TEXT,
  avg_lead_time_days    TEXT,
  country               TEXT
);

/* Creating STAGING tables
- Learning Notes:
STAGING = cleaned + typed layer.
   Adds constraints (NOT NULL, CHECKs) to catch bad data early.
   Converts raw strings into correct types (date, int, numeric) */

CREATE TABLE IF NOT EXISTS staging.products (
  product_id     TEXT PRIMARY KEY,
  product_name   TEXT NOT NULL,
  category       TEXT NOT NULL,
  sub_category   TEXT,
  unit_cost      NUMERIC(10,2) NOT NULL CHECK (unit_cost >= 0),
  unit_price     NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
  supplier_id    TEXT
);

CREATE TABLE IF NOT EXISTS staging.stores (
  store_id       TEXT PRIMARY KEY,
  store_name     TEXT NOT NULL,
  region         TEXT NOT NULL,
  country        TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS staging.orders (
  order_id       TEXT NOT NULL,
  order_date     DATE NOT NULL,
  store_id       TEXT NOT NULL,
  customer_id    TEXT NOT NULL,
  product_id     TEXT NOT NULL,
  quantity       INT NOT NULL CHECK (quantity > 0),
  unit_price     NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
  discount_pct   NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (discount_pct >= 0 AND discount_pct <= 100),
  PRIMARY KEY (order_id, product_id)
);

CREATE TABLE IF NOT EXISTS staging.inventory_snapshots (
  snapshot_date  DATE NOT NULL,
  store_id       TEXT NOT NULL,
  product_id     TEXT NOT NULL,
  on_hand_qty    INT NOT NULL CHECK (on_hand_qty >= 0),
  PRIMARY KEY (snapshot_date, store_id, product_id)
);

CREATE TABLE IF NOT EXISTS staging.suppliers (
  supplier_id          TEXT PRIMARY KEY,
  supplier_name        TEXT NOT NULL,
  avg_lead_time_days   INT CHECK (avg_lead_time_days IS NULL OR avg_lead_time_days >= 0),
  country              TEXT
);

/* Creating CORE tables
- Learning Notes:
CORE = analytics model (star schema).
   dims = descriptive entities (product, store)
   facts = events/snapshots (order lines, inventory snapshots)
   This supports fast joins and consistent reporting. */

CREATE TABLE IF NOT EXISTS core.dim_product (
  product_id     TEXT PRIMARY KEY,
  product_name   TEXT NOT NULL,
  category       TEXT NOT NULL,
  sub_category   TEXT,
  unit_cost      NUMERIC(10,2) NOT NULL,
  unit_price     NUMERIC(10,2) NOT NULL,
  supplier_id    TEXT,
  is_active      BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS core.dim_store (
  store_id       TEXT PRIMARY KEY,
  store_name     TEXT NOT NULL,
  region         TEXT NOT NULL,
  country        TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS core.fact_order_line (
  order_id       TEXT NOT NULL,
  order_date     DATE NOT NULL,
  store_id       TEXT NOT NULL REFERENCES core.dim_store(store_id),
  customer_id    TEXT NOT NULL,
  product_id     TEXT NOT NULL REFERENCES core.dim_product(product_id),
  quantity       INT NOT NULL,
  unit_price     NUMERIC(10,2) NOT NULL,
  discount_pct   NUMERIC(5,2) NOT NULL,
  net_revenue    NUMERIC(12,2) NOT NULL,
  PRIMARY KEY (order_id, product_id)
);

CREATE TABLE IF NOT EXISTS core.fact_inventory_snapshot (
  snapshot_date  DATE NOT NULL,
  store_id       TEXT NOT NULL REFERENCES core.dim_store(store_id),
  product_id     TEXT NOT NULL REFERENCES core.dim_product(product_id),
  on_hand_qty    INT NOT NULL,
  PRIMARY KEY (snapshot_date, store_id, product_id)
);

CREATE TABLE IF NOT EXISTS core.dim_supplier (
  supplier_id          TEXT PRIMARY KEY,
  supplier_name        TEXT NOT NULL,
  avg_lead_time_days   INT,
  country              TEXT,
  is_active            BOOLEAN NOT NULL DEFAULT TRUE
);

/* Creating Indexes
- Learning Notes:
Indexes improve query performance.
   Target columns used frequently in filters/joins:
   - order_date for time-based analysis
   - (store_id, product_id) for product/store rollups */

CREATE INDEX IF NOT EXISTS idx_orders_date ON core.fact_order_line(order_date);
CREATE INDEX IF NOT EXISTS idx_orders_store_product ON core.fact_order_line(store_id, product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_store_product ON core.fact_inventory_snapshot(store_id, product_id);

/* The transformation steps
- RAW -> STAGING
- Learning Notes:
RAW → STAGING transforms:
   - TRIM() removes whitespace issues
   - NULLIF(x,'') turns blanks into NULLs
   - Casts to numeric/int/date for reliable maths
   - ON CONFLICT makes loads re-runnable (upsert pattern) */

INSERT INTO staging.products (product_id, product_name, category, sub_category, unit_cost, unit_price, supplier_id)
SELECT DISTINCT
  TRIM(product_id),
  TRIM(product_name),
  TRIM(category),
  NULLIF(TRIM(sub_category), ''),
  (unit_cost)::numeric,
  (unit_price)::numeric,
  NULLIF(TRIM(supplier_id), '')
FROM raw.products
WHERE product_id IS NOT NULL
ON CONFLICT (product_id) DO UPDATE SET
  product_name = EXCLUDED.product_name,
  category = EXCLUDED.category,
  sub_category = EXCLUDED.sub_category,
  unit_cost = EXCLUDED.unit_cost,
  unit_price = EXCLUDED.unit_price,
  supplier_id = EXCLUDED.supplier_id;

INSERT INTO staging.stores (store_id, store_name, region, country)
SELECT DISTINCT
  TRIM(store_id),
  TRIM(store_name),
  TRIM(region),
  TRIM(country)
FROM raw.stores
WHERE store_id IS NOT NULL
ON CONFLICT (store_id) DO UPDATE SET
  store_name = EXCLUDED.store_name,
  region = EXCLUDED.region,
  country = EXCLUDED.country;

INSERT INTO staging.orders (order_id, order_date, store_id, customer_id, product_id, quantity, unit_price, discount_pct)
SELECT
  TRIM(order_id),
  TO_DATE(TRIM(order_date), 'YYYY-MM-DD'),
  TRIM(store_id),
  TRIM(customer_id),
  TRIM(product_id),
  (quantity)::int,
  (unit_price)::numeric,
  COALESCE(NULLIF(discount_pct,''),'0')::numeric
FROM raw.orders
WHERE order_id IS NOT NULL AND product_id IS NOT NULL
ON CONFLICT (order_id, product_id) DO UPDATE SET
  order_date = EXCLUDED.order_date,
  store_id = EXCLUDED.store_id,
  customer_id = EXCLUDED.customer_id,
  quantity = EXCLUDED.quantity,
  unit_price = EXCLUDED.unit_price,
  discount_pct = EXCLUDED.discount_pct;

INSERT INTO staging.inventory_snapshots (snapshot_date, store_id, product_id, on_hand_qty)
SELECT
  TO_DATE(TRIM(snapshot_date), 'YYYY-MM-DD'),
  TRIM(store_id),
  TRIM(product_id),
  (on_hand_qty)::int
FROM raw.inventory_snapshots
WHERE snapshot_date IS NOT NULL AND product_id IS NOT NULL
ON CONFLICT (snapshot_date, store_id, product_id) DO UPDATE SET
  on_hand_qty = EXCLUDED.on_hand_qty;

INSERT INTO staging.suppliers (supplier_id, supplier_name, avg_lead_time_days, country)
SELECT DISTINCT
  TRIM(supplier_id),
  TRIM(supplier_name),
  NULLIF(TRIM(avg_lead_time_days), '')::int,
  NULLIF(TRIM(country), '')
FROM raw.suppliers
WHERE supplier_id IS NOT NULL
ON CONFLICT (supplier_id) DO UPDATE SET
  supplier_name = EXCLUDED.supplier_name,
  avg_lead_time_days = EXCLUDED.avg_lead_time_days,
  country = EXCLUDED.country;

/* STAGING -> CORE
- Learning Notes:
STAGING → CORE:
   Core dims/facts are curated outputs.
   net_revenue is calculated once here so marts don’t repeat logic.
   Keeps reporting consistent across dashboards. */

INSERT INTO core.dim_product (product_id, product_name, category, sub_category, unit_cost, unit_price, supplier_id)
SELECT product_id, product_name, category, sub_category, unit_cost, unit_price, supplier_id
FROM staging.products
ON CONFLICT (product_id) DO UPDATE SET
  product_name = EXCLUDED.product_name,
  category = EXCLUDED.category,
  sub_category = EXCLUDED.sub_category,
  unit_cost = EXCLUDED.unit_cost,
  unit_price = EXCLUDED.unit_price,
  supplier_id = EXCLUDED.supplier_id;

INSERT INTO core.fact_order_line (order_id, order_date, store_id, customer_id, product_id, quantity, unit_price, discount_pct, net_revenue)
SELECT
  o.order_id,
  o.order_date,
  o.store_id,
  o.customer_id,
  o.product_id,
  o.quantity,
  o.unit_price,
  o.discount_pct,
  ROUND(o.quantity * o.unit_price * (1 - o.discount_pct/100.0), 2) AS net_revenue
FROM staging.orders o
ON CONFLICT (order_id, product_id) DO UPDATE SET
  order_date = EXCLUDED.order_date,
  store_id = EXCLUDED.store_id,
  customer_id = EXCLUDED.customer_id,
  quantity = EXCLUDED.quantity,
  unit_price = EXCLUDED.unit_price,
  discount_pct = EXCLUDED.discount_pct,
  net_revenue = EXCLUDED.net_revenue;

INSERT INTO core.fact_inventory_snapshot (snapshot_date, store_id, product_id, on_hand_qty)
SELECT snapshot_date, store_id, product_id, on_hand_qty
FROM staging.inventory_snapshots
ON CONFLICT (snapshot_date, store_id, product_id) DO UPDATE SET
  on_hand_qty = EXCLUDED.on_hand_qty;

INSERT INTO core.dim_supplier (supplier_id, supplier_name, avg_lead_time_days, country)
SELECT supplier_id, supplier_name, avg_lead_time_days, country
FROM staging.suppliers
ON CONFLICT (supplier_id) DO UPDATE SET
  supplier_name = EXCLUDED.supplier_name,
  avg_lead_time_days = EXCLUDED.avg_lead_time_days,
  country = EXCLUDED.country;

/* Business Marts 
- Daily Sales Velocity (last 30 days)
- Learning Notes:
MART: Daily sales velocity = average units/day over last 30 days.
   Business use: demand signal for replenishment + forecasting baseline. */

CREATE OR REPLACE VIEW marts.daily_sales_velocity AS
SELECT
  store_id,
  product_id,
  ROUND(SUM(quantity) / 30.0, 2) AS avg_daily_units
FROM core.fact_order_line
WHERE order_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY store_id, product_id;

/* - Stockout Risk (days of cover)
- Learning Notes
MART: Stockout risk = 'days of cover'
   days_of_cover = on_hand_qty / avg_daily_units
   Business use: highlight items likely to go out of stock soon. */

CREATE OR REPLACE VIEW marts.stockout_risk AS
SELECT
  i.snapshot_date,
  i.store_id,
  i.product_id,
  i.on_hand_qty,
  v.avg_daily_units,
  CASE
    WHEN v.avg_daily_units = 0 THEN NULL
    ELSE ROUND(i.on_hand_qty / v.avg_daily_units, 1)
  END AS days_of_cover
FROM core.fact_inventory_snapshot i
LEFT JOIN marts.daily_sales_velocity v
  ON i.store_id = v.store_id AND i.product_id = v.product_id;

/* - Reorder Recommendations
- Rule: reorder if days_of_cover < 7 target 14 days
- Learning Notes:
MART: Reorder recommendations
   Rule: reorder if days_of_cover < 7, target 14 days cover.
   reorder_qty = ceil((14 - days_of_cover) * avg_daily_units)
   Business use: actionable purchase list for replenishment planning. */

CREATE OR REPLACE VIEW marts.reorder_recommendations AS
SELECT
  r.snapshot_date,
  r.store_id,
  r.product_id,
  r.on_hand_qty,
  r.avg_daily_units,
  r.days_of_cover,
  CASE
    WHEN r.avg_daily_units IS NULL OR r.avg_daily_units = 0 THEN 0
    WHEN r.days_of_cover IS NULL THEN 0
    WHEN r.days_of_cover < 7 THEN CEIL((14 - r.days_of_cover) * r.avg_daily_units)
    ELSE 0
  END AS reorder_qty
FROM marts.stockout_risk r;

SELECT 'products' AS table, COUNT(*) FROM raw.products
UNION ALL SELECT 'stores', COUNT(*) FROM raw.stores
UNION ALL SELECT 'suppliers', COUNT(*) FROM raw.suppliers
UNION ALL SELECT 'orders', COUNT(*) FROM raw.orders
UNION ALL SELECT 'inventory_snapshots', COUNT(*) FROM raw.inventory_snapshots;

/* RAW → STAGING */

INSERT INTO staging.products (product_id, product_name, category, sub_category, unit_cost, unit_price, supplier_id)
SELECT DISTINCT
  TRIM(product_id),
  TRIM(product_name),
  TRIM(category),
  NULLIF(TRIM(sub_category), ''),
  (unit_cost)::numeric,
  (unit_price)::numeric,
  NULLIF(TRIM(supplier_id), '')
FROM raw.products
WHERE product_id IS NOT NULL
ON CONFLICT (product_id) DO UPDATE SET
  product_name  = EXCLUDED.product_name,
  category      = EXCLUDED.category,
  sub_category  = EXCLUDED.sub_category,
  unit_cost     = EXCLUDED.unit_cost,
  unit_price    = EXCLUDED.unit_price,
  supplier_id   = EXCLUDED.supplier_id;

INSERT INTO staging.stores (store_id, store_name, region, country)
SELECT DISTINCT
  TRIM(store_id),
  TRIM(store_name),
  TRIM(region),
  TRIM(country)
FROM raw.stores
WHERE store_id IS NOT NULL
ON CONFLICT (store_id) DO UPDATE SET
  store_name = EXCLUDED.store_name,
  region     = EXCLUDED.region,
  country    = EXCLUDED.country;

INSERT INTO staging.orders (order_id, order_date, store_id, customer_id, product_id, quantity, unit_price, discount_pct)
SELECT
  TRIM(order_id),
  TO_DATE(TRIM(order_date), 'YYYY-MM-DD'),
  TRIM(store_id),
  TRIM(customer_id),
  TRIM(product_id),
  (quantity)::int,
  (unit_price)::numeric,
  COALESCE(NULLIF(discount_pct,''), '0')::numeric
FROM raw.orders
WHERE order_id IS NOT NULL AND product_id IS NOT NULL
ON CONFLICT (order_id, product_id) DO UPDATE SET
  order_date    = EXCLUDED.order_date,
  store_id      = EXCLUDED.store_id,
  customer_id   = EXCLUDED.customer_id,
  quantity      = EXCLUDED.quantity,
  unit_price    = EXCLUDED.unit_price,
  discount_pct  = EXCLUDED.discount_pct;

INSERT INTO staging.inventory_snapshots (snapshot_date, store_id, product_id, on_hand_qty)
SELECT
  TO_DATE(TRIM(snapshot_date), 'YYYY-MM-DD'),
  TRIM(store_id),
  TRIM(product_id),
  (on_hand_qty)::int
FROM raw.inventory_snapshots
WHERE snapshot_date IS NOT NULL AND product_id IS NOT NULL
ON CONFLICT (snapshot_date, store_id, product_id) DO UPDATE SET
  on_hand_qty = EXCLUDED.on_hand_qty;

SELECT 'staging.products' t, COUNT(*) c FROM staging.products
UNION ALL SELECT 'staging.stores', COUNT(*) FROM staging.stores
UNION ALL SELECT 'staging.orders', COUNT(*) FROM staging.orders
UNION ALL SELECT 'staging.inventory_snapshots', COUNT(*) FROM staging.inventory_snapshots;

/* STAGING → CORE */

INSERT INTO core.dim_product (product_id, product_name, category, sub_category, unit_cost, unit_price, supplier_id)
SELECT product_id, product_name, category, sub_category, unit_cost, unit_price, supplier_id
FROM staging.products
ON CONFLICT (product_id) DO UPDATE SET
  product_name = EXCLUDED.product_name,
  category     = EXCLUDED.category,
  sub_category = EXCLUDED.sub_category,
  unit_cost    = EXCLUDED.unit_cost,
  unit_price   = EXCLUDED.unit_price,
  supplier_id  = EXCLUDED.supplier_id;

INSERT INTO core.dim_store (store_id, store_name, region, country)
SELECT store_id, store_name, region, country
FROM staging.stores
ON CONFLICT (store_id) DO UPDATE SET
  store_name = EXCLUDED.store_name,
  region     = EXCLUDED.region,
  country    = EXCLUDED.country;

INSERT INTO core.fact_order_line (order_id, order_date, store_id, customer_id, product_id, quantity, unit_price, discount_pct, net_revenue)
SELECT
  o.order_id,
  o.order_date,
  o.store_id,
  o.customer_id,
  o.product_id,
  o.quantity,
  o.unit_price,
  o.discount_pct,
  ROUND(o.quantity * o.unit_price * (1 - o.discount_pct/100.0), 2) AS net_revenue
FROM staging.orders o
ON CONFLICT (order_id, product_id) DO UPDATE SET
  order_date   = EXCLUDED.order_date,
  store_id     = EXCLUDED.store_id,
  customer_id  = EXCLUDED.customer_id,
  quantity     = EXCLUDED.quantity,
  unit_price   = EXCLUDED.unit_price,
  discount_pct = EXCLUDED.discount_pct,
  net_revenue  = EXCLUDED.net_revenue;

INSERT INTO core.fact_inventory_snapshot (snapshot_date, store_id, product_id, on_hand_qty)
SELECT snapshot_date, store_id, product_id, on_hand_qty
FROM staging.inventory_snapshots
ON CONFLICT (snapshot_date, store_id, product_id) DO UPDATE SET
  on_hand_qty = EXCLUDED.on_hand_qty;

SELECT 'core.dim_product' t, COUNT(*) c FROM core.dim_product
UNION ALL SELECT 'core.dim_store', COUNT(*) FROM core.dim_store
UNION ALL SELECT 'core.fact_order_line', COUNT(*) FROM core.fact_order_line
UNION ALL SELECT 'core.fact_inventory_snapshot', COUNT(*) FROM core.fact_inventory_snapshot;

/* MARTS */

CREATE OR REPLACE VIEW marts.daily_sales_velocity AS
SELECT
  store_id,
  product_id,
  ROUND(SUM(quantity) / 30.0, 2) AS avg_daily_units
FROM core.fact_order_line
WHERE order_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY store_id, product_id;

CREATE OR REPLACE VIEW marts.stockout_risk AS
SELECT
  i.snapshot_date,
  i.store_id,
  i.product_id,
  i.on_hand_qty,
  v.avg_daily_units,
  CASE
    WHEN v.avg_daily_units = 0 THEN NULL
    ELSE ROUND(i.on_hand_qty / v.avg_daily_units, 1)
  END AS days_of_cover
FROM core.fact_inventory_snapshot i
LEFT JOIN marts.daily_sales_velocity v
  ON i.store_id = v.store_id AND i.product_id = v.product_id;

CREATE OR REPLACE VIEW marts.reorder_recommendations AS
SELECT
  r.snapshot_date,
  r.store_id,
  r.product_id,
  r.on_hand_qty,
  r.avg_daily_units,
  r.days_of_cover,
  CASE
    WHEN r.avg_daily_units IS NULL OR r.avg_daily_units = 0 THEN 0
    WHEN r.days_of_cover IS NULL THEN 0
    WHEN r.days_of_cover < 7 THEN CEIL((14 - r.days_of_cover) * r.avg_daily_units)
    ELSE 0
  END AS reorder_qty
FROM marts.stockout_risk r;

SELECT COUNT(*) FROM marts.daily_sales_velocity;
SELECT COUNT(*) FROM marts.stockout_risk;
SELECT COUNT(*) FROM marts.reorder_recommendations;

SELECT * FROM marts.reorder_recommendations
ORDER BY reorder_qty DESC
LIMIT 20;

/*
DATA ENGINEERING PIPELINE

Source → CSV files
Raw layer → ingestion tables
Staging → cleaned & typed
Core → dimensional warehouse model
Marts → analytics & business logic

Author: Rory Moir
Project: Retail Inventory Optimization Pipeline
*/