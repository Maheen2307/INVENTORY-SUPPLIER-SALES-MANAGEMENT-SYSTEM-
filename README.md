# Inventory, Supplier & Sales Management System (ISMS)

![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-4479A1?style=for-the-badge&logo=postgresql&logoColor=white)

## 📖 Objective
A complete **relational database system** for managing inventory, suppliers, warehouses, employees, customers, orders, payments, shipments, and returns. Demonstrates **database design, integrity constraints, triggers, views, CTEs, window functions, and analytical reporting** using MySQL.

## 🛠️ Tech Stack
- **Database:** MySQL 8.0+
- **SQL Features:** DDL, DML, Triggers, Views, CTEs, Window Functions
- **Tools:** MySQL Workbench / Command Line

## ✨ Features
- 15 normalized tables with **foreign keys, CHECK constraints, ENUMs, and indexes**
- **Triggers** to automate stock deduction, order total calculation, and stock adjustments
- **Views** for master inventory reporting
- **15 analytical queries** including:
  - Regional valuation & tax rates
  - Warehouse stock valuation
  - Supplier performance & ratings
  - Category rankings using `RANK()`
  - Low-stock reorder alerts
  - Employee sales performance
  - Premium customer lifetime value (CTE)
  - Payment audit & outstanding balance
  - Top-selling products
  - Inventory transaction log
  - Payment mode summary
  - Shipment status breakdown
  - Return & refund audit
  - Monthly revenue trend using `LAG()`

## 🧠 SQL Concepts Used
| Concept | Purpose |
|---------|---------|
| **Normalization (3NF)** | Avoid redundancy, ensure data integrity |
| **Foreign Keys** | Enforce referential integrity |
| **CHECK Constraints** | Validate data ranges (stock, price, status) |
| **ENUM** | Restrict transaction types |
| **Indexes** | Optimise query performance |
| **Triggers** | Automate stock deduction and order total updates |
| **Views** | Simplify complex queries (master inventory) |
| **CTEs** | Break down complex reporting (LTV, monthly trends) |
| **Window Functions** | `RANK()`, `LAG()` for analytical insights |

## 🖼️ Screenshots
| ER Diagram | Tables Created | Products Data | Low Stock | Top Selling |
|------------|----------------|---------------|-----------|-------------|
| ![ER](screenshots/erd.png) | ![Tables](screenshots/tables_created.png) | ![Data](screenshots/products_data.png) | ![LowStock](screenshots/low_stock.png) | ![Top](screenshots/top_selling.png) |

## ⚙️ How to Run
1. Install MySQL Server 8.0+
2. Open terminal / MySQL Workbench
3. Run the script:
```bash
mysql -u root -p < ISMS.sql
```
4. The script creates the database, tables, sample data, and executes all 15 reports.

## 📁 Repository Structure
```plaintext
ISMS/
├── screenshots/
│   ├── er_diagram.png
│   ├── tables_created.png
│   ├── products_data.png
│   ├── low_stock.png
│   └── top_selling.png
├── ISMS.sql
├── LICENSE
└── README.md
```

## 📋 Sample Output (Report #6 – Low-Stock Alert)
```plaintext
+---------------------+----------------+---------------+----------+-----------------------+
| ProductName         | WarehouseName  | StockQuantity | MinLevel | UnitsNeededToReorder  |
+---------------------+----------------+---------------+----------+-----------------------+
| Macbook Pro         | LHR-Main       |             3 |        5 |                     2 |
| Sofa Set            | MTN-Storage    |             5 |        2 |                    -3 |
+---------------------+----------------+---------------+----------+-----------------------+
```

## ⚠️ Limitations
- No stored procedures for common operations (e.g., place order)
- Trigger logic for `UPDATE` on `OrderDetails` handles stock changes but does not validate new stock before update
- No user authentication / roles in database
- Designed for demo/learning, not production-ready

## 🚀 Future Improvements
- Add stored procedures & functions for business logic
- Implement a frontend (Python/Java + web dashboard)
- Add full user management and security
- Extend triggers to cover returns and cancellations
- Move to PostgreSQL or SQL Server for advanced features

## 📄 License
This project is licensed under the MIT License.
