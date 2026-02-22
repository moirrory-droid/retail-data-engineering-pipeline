# retail-data-engineering-pipeline
Retail Data Engineering Pipeline

PostgreSQL ELT pipeline (raw → staging → core → marts)

Overview

This project builds an end-to-end data engineering pipeline that ingests operational retail data, transforms it into a structured warehouse model, and produces business-ready outputs. The goal is to simulate how raw operational data moves through a modern warehouse architecture and becomes reliable, analytics-ready datasets.

Objective

Design and implement a reproducible data pipeline that:

1. ingests raw source files
2. standardises and validates data
3. builds dimensional warehouse models
4. generates operational insights

This mirrors the responsibilities of a junior data engineer working with transactional business systems.

Architecture
Source CSVs
   ↓
RAW (landing zone)
   ↓
STAGING (clean + typed)
   ↓
CORE (dimensional warehouse)
   ↓
MARTS (analytics outputs)

Tech Stack
1. PostgreSQL
2. SQL (data modelling & transformations)
3. VS Code
4. Git & GitHub

Data Pipeline Design

Raw Layer
Stores data exactly as received from source systems.

Purpose:

1. preserve original data
2. allow replayability
3. enable auditing/debugging

Tables:

1. raw.products
2. raw.stores
3. raw.suppliers
4. raw.orders
5. raw.inventory_snapshots

Staging Layer

Data cleaning and standardisation layer.

Processes:

1. trimming whitespace
2. handling null values
3. casting data types
4. deduplicating records

Purpose:

1. improve data quality
2. prepare for warehouse modelling

Core Layer

Dimensional warehouse model using fact and dimension tables.

Dimensions:

1. dim_product
2. dim_store
3. dim_supplier

Facts:

1. fact_order_line
2. fact_inventory_snapshot

Includes:

1. relationships between entities
2. calculated metrics (net revenue)

Purpose:

1. provide stable, analytics-ready datasets
2. support scalable joins and reporting

Marts Layer

Business-focused analytical outputs built from core tables.

Views created:

1. Daily Sales Velocity
2. Average units sold per store/product over the last 30 days.

Stockout Risk

1. Calculates inventory “days of cover”.
2. Reorder Recommendations
3. Generates suggested replenishment quantities using demand and stock levels.

Purpose:

1. convert warehouse data into decision-support outputs
2. separate business logic from raw transformations

Engineering Practices Applied

1. layered schema design (raw → staging → core → marts)
2. ELT transformation pattern
3. idempotent SQL pipelines
4. upserts using ON CONFLICT DO UPDATE
5. data quality handling with casting and constraints
6. dimensional modelling (facts & dimensions)

Example Output Queries

SELECT * FROM marts.reorder_recommendations ORDER BY reorder_qty DESC LIMIT 20; SELECT * FROM marts.stockout_risk ORDER BY days_of_cover ASC;

What This Project Demonstrates

1. building structured data pipelines
2. transforming messy source data into warehouse models
3. implementing repeatable SQL workflows
4. modelling operational business entities
5. producing decision-ready datasets

Next Steps / Improvements

1. automate ingestion using Python
2. introduce scheduling/orchestration
3. integrate supplier lead-time into replenishment logic
4. containerise database environment
5. add monitoring & validation checks

Author

Rory Moir
Transitioning into data engineering, building practical pipelines focused on real operational use cases.

<img width="1552" height="902" alt="Screenshot 2026-02-22 at 21 35 34" src="https://github.com/user-attachments/assets/f22e008a-0f22-4da1-b0dc-67e3db782c37" />

<img width="1552" height="902" alt="Screenshot 2026-02-22 at 21 36 24" src="https://github.com/user-attachments/assets/5b93c71c-7b5c-4287-b702-aaa410e0dda2" />

<img width="1552" height="902" alt="Screenshot 2026-02-22 at 21 37 33" src="https://github.com/user-attachments/assets/e161d56d-97de-4a49-9565-d30a93e7d781" />

<img width="1552" height="902" alt="Screenshot 2026-02-22 at 21 39 06" src="https://github.com/user-attachments/assets/479b7a39-5326-42a1-a4f7-80260d1a7ba5" />

