# Vehicle Rental Management System (MySQL Individual Project 16)

A MySQL database for a vehicle rental business. It stores customers, vehicles, bookings, agreements, payments, returns, maintenance records and penalties.

## What is inside
- Database: `vehicle_rental_db`
- 10 tables, 2 views, 4 stored procedures, 1 trigger, 1 index
- 84 automated test cases (`07_test_cases.sql`)

## Requirements
- MySQL 8.0.16 or newer (needed for CHECK constraints), or MariaDB 10.5+
- MySQL Workbench or the `mysql` command-line client

## How to run (in this order)
| Step | File | Purpose |
|------|------|---------|
| 1 | `01_schema.sql` | Creates the database and 10 tables |
| 2 | `02_sample_data.sql` | Loads the sample data |
| 3 | `04_views_and_reports.sql` | 2 views and 5 business reports |
| 4 | `05_programmability.sql` | Trigger, 4 stored procedures, index |
| 5 | `03_queries.sql` | Query demonstrations (SELECT, DML, JOINs, subqueries) |
| 6 | `06_transactions_demo.sql` | COMMIT / ROLLBACK, procedure calls, EXPLAIN |
| 7 | `07_test_cases.sql` | 84 automated PASS / FAIL tests |

Command line example:

    mysql -u root -p < 01_schema.sql
    mysql -u root -p < 02_sample_data.sql
    mysql -u root -p < 04_views_and_reports.sql
    mysql -u root -p < 05_programmability.sql

`test_cases.txt` lists every test with its expected and actual result.

## Business rules
- Total amount = agreed daily rate x rental days, where rental days = DATEDIFF(end, start) + 1
- Advance payment = 50% of the total. Final payment = unpaid balance + all penalties
- Penalty = days late x late fee per day, plus damage and fuel charges
- A vehicle must be Available to be booked
- Foreign keys use ON DELETE RESTRICT, so rental history cannot be deleted by accident