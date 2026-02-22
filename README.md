# retail-data-engineering-pipeline
Retail Data Engineering Pipeline

End-to-end ELT pipeline using PostgreSQL (raw → staging → core → marts)

Overview

This project builds a simple but realistic data engineering pipeline to ingest operational retail data, transform it into a structured warehouse model, and generate business insights around inventory, sales, and stockout risk. The pipeline takes raw CSV data, loads it into PostgreSQL, cleans and standardises it, and produces analytics-ready outputs for decision making.

Problem Statement

Retail operations rely on accurate data to manage:

product sales

inventory levels

stockout risk

replenishment planning

Raw operational exports are often messy and not immediately usable.

This project simulates how a data engineer would:

1. ingest source data

2. standardise and validate it

3. build a warehouse model

4. generate business-ready outputs

Architecture

CSV files
   ↓
RAW schema (landing zone)
   ↓
STAGING schema (cleaned + typed)
   ↓
CORE schema (dimensional warehouse)
   ↓
MARTS schema (analytics + decision support)

Tech Stack

PostgreSQL
VS Code
SQL (data modelling & transformations)
Git / GitHub
Data Sources
CSV files simulating operational 

retail systems:
products
stores
suppliers
orders
inventory snapshots

Pipeline Stages
1) Raw Ingestion

Source CSVs are loaded into the raw schema using PostgreSQL \copy.

Purpose:

preserve original source data

enable reprocessing

maintain traceability

2) Staging Layer

Data is cleaned and standardised:

whitespace trimmed

blank values converted to NULL

data types cast (TEXT → INT / NUMERIC / DATE)

constraints applied

Purpose:

improve data quality

prepare for warehouse modelling

3) Core Warehouse Model

Dimensional model created using:

Dimensions

dim_product

dim_store

dim_supplier

Facts

fact_order_line

fact_inventory_snapshot

Derived metrics added:

net revenue calculations

relationships between entities

Purpose:

stable analytics-ready structure

consistent joins

reliable reporting

4) Marts Layer (Business Outputs)

Views created to support decision-making:

Daily Sales Velocity

Average units sold per product/store over last 30 days.

Used for:

demand estimation

inventory planning

Stockout Risk

Calculates "days of cover":

on_hand_qty / avg_daily_units

Used for:

identifying potential stock shortages

Reorder Recommendations

Simple business rule:

If days_of_cover < 7 → suggest replenishment

Used for:

operational decision support

Key Engineering Concepts Used

ELT pipeline design

schema layering (raw → staging → core → marts)

dimensional modelling (facts & dimensions)

idempotent transformations

upserts using ON CONFLICT DO UPDATE

data quality handling with casting & validation

Example Queries

Top stockout risk products

SELECT * FROM marts.stockout_risk ORDER BY days_of_cover ASC LIMIT 20;

Products requiring replenishment

SELECT * FROM marts.reorder_recommendations WHERE reorder_qty > 0 ORDER BY reorder_qty DESC;

Learning Outcomes

This project helped me understand:

1. how raw operational data becomes analytics-ready
2. when to use staging vs core models
3. how to structure warehouse schemas
4. safe incremental loading using upserts
5. how SQL supports business decision logic

Next Improvements

Planned enhancements:

1. automate ingestion with Python
2. schedule pipeline execution
3. add supplier lead-time into reorder logic
4. build dashboard layer

Author

Rory Moir
Transitioning into data engineering with a focus on building practical, business-oriented data pipelines.

<img width="1552" height="902" alt="Screenshot 2026-02-22 at 21 35 34" src="https://github.com/user-attachments/assets/f22e008a-0f22-4da1-b0dc-67e3db782c37" />

<img width="1552" height="902" alt="Screenshot 2026-02-22 at 21 36 24" src="https://github.com/user-attachments/assets/5b93c71c-7b5c-4287-b702-aaa410e0dda2" />

<img width="1552" height="902" alt="Screenshot 2026-02-22 at 21 37 33" src="https://github.com/user-attachments/assets/e161d56d-97de-4a49-9565-d30a93e7d781" />

<img width="1552" height="902" alt="Screenshot 2026-02-22 at 21 39 06" src="https://github.com/user-attachments/assets/479b7a39-5326-42a1-a4f7-80260d1a7ba5" />

