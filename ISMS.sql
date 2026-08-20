/***************************************************************
    INVENTORY, SUPPLIER & SALES MANAGEMENT SYSTEM (ISMS) 
*****************************************************************/

DROP DATABASE IF EXISTS InventorySystemPro;
CREATE DATABASE InventorySystemPro;
USE InventorySystemPro;

-- ============================================================================
-- 1. TABLES WITH INTEGRITY CONSTRAINTS (CHECK & ENUM)
-- ============================================================================

CREATE TABLE Regions (
    RegionID INT AUTO_INCREMENT PRIMARY KEY,
    RegionName VARCHAR(50) NOT NULL,
    TaxRate DECIMAL(5,2) NOT NULL CHECK (TaxRate >= 0)
);

CREATE TABLE Warehouses (
    WarehouseID INT AUTO_INCREMENT PRIMARY KEY,
    WarehouseName VARCHAR(100) NOT NULL,
    Location VARCHAR(150),
    RegionID INT,
    FOREIGN KEY (RegionID) REFERENCES Regions(RegionID) ON DELETE SET NULL
);

CREATE TABLE Suppliers (
    SupplierID INT AUTO_INCREMENT PRIMARY KEY,
    SupplierName VARCHAR(100) NOT NULL,
    ContactEmail VARCHAR(100),
    City VARCHAR(50),
    Rating INT CHECK (Rating BETWEEN 1 AND 5)
);

CREATE TABLE Categories (
    CategoryID INT AUTO_INCREMENT PRIMARY KEY,
    CategoryName VARCHAR(50) NOT NULL,
    ShelfLifeDays INT CHECK (ShelfLifeDays > 0)
);

CREATE TABLE Products (
    ProductID INT AUTO_INCREMENT PRIMARY KEY,
    ProductName VARCHAR(100) NOT NULL,
    Price DECIMAL(10,2) NOT NULL CHECK (Price >= 0),
    CategoryID INT,
    SupplierID INT,
    WarehouseID INT,
    StockQuantity INT DEFAULT 0 CHECK (StockQuantity >= 0),
    MinLevel INT DEFAULT 5 CHECK (MinLevel >= 0),
    FOREIGN KEY (CategoryID) REFERENCES Categories(CategoryID) ON DELETE SET NULL,
    FOREIGN KEY (SupplierID) REFERENCES Suppliers(SupplierID) ON DELETE SET NULL,
    FOREIGN KEY (WarehouseID) REFERENCES Warehouses(WarehouseID) ON DELETE SET NULL
);

CREATE TABLE Employees (
    EmployeeID INT AUTO_INCREMENT PRIMARY KEY,
    EmpName VARCHAR(100) NOT NULL,
    JobTitle VARCHAR(50),
    Salary DECIMAL(10,2) CHECK (Salary >= 0),
    WarehouseID INT,
    FOREIGN KEY (WarehouseID) REFERENCES Warehouses(WarehouseID) ON DELETE SET NULL
);

CREATE TABLE Customers (
    CustomerID INT AUTO_INCREMENT PRIMARY KEY,
    CustomerName VARCHAR(100) NOT NULL,
    Phone VARCHAR(20),
    City VARCHAR(50),
    IsPremium TINYINT(1) DEFAULT 0
);

-- UPDATED: Added CHECK constraint for OrderStatus
CREATE TABLE Orders (
    OrderID INT AUTO_INCREMENT PRIMARY KEY,
    CustomerID INT,
    EmployeeID INT,
    OrderDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    TotalAmount DECIMAL(12,2) DEFAULT 0.00 CHECK (TotalAmount >= 0),
    OrderStatus VARCHAR(20) DEFAULT 'Pending' 
        CHECK (OrderStatus IN ('Pending', 'Processing', 'Shipped', 'Completed', 'Cancelled')),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID) ON DELETE SET NULL,
    FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID) ON DELETE SET NULL
);

CREATE TABLE OrderDetails (
    DetailID INT AUTO_INCREMENT PRIMARY KEY,
    OrderID INT,
    ProductID INT,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    UnitPrice DECIMAL(10,2) NOT NULL CHECK (UnitPrice >= 0),
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID) ON DELETE CASCADE,
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID) ON DELETE RESTRICT
);

CREATE TABLE InventoryTransactions (
    TransactionID INT AUTO_INCREMENT PRIMARY KEY,
    ProductID INT,
    TransType ENUM('IN', 'OUT', 'RETURN', 'ADJUSTMENT') NOT NULL,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    ReferenceType VARCHAR(30),
    ReferenceID INT,
    TransDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID) ON DELETE CASCADE
);

CREATE TABLE Payments (
    PaymentID INT AUTO_INCREMENT PRIMARY KEY,
    OrderID INT,
    PaymentMode VARCHAR(30),
    AmountPaid DECIMAL(10,2) CHECK (AmountPaid >= 0),
    PaymentDate DATE,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID) ON DELETE CASCADE
);

-- UPDATED: Added CHECK constraint for Shipment Status
CREATE TABLE Shipments (
    ShipmentID INT AUTO_INCREMENT PRIMARY KEY,
    OrderID INT,
    Carrier VARCHAR(50),
    TrackingNumber VARCHAR(50),
    ShipDate DATE,
    Status VARCHAR(20) DEFAULT 'Processing' 
        CHECK (Status IN ('Processing', 'In Transit', 'Delivered', 'Failed')),
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID) ON DELETE CASCADE
);

CREATE TABLE ProductReturns (
    ReturnID INT AUTO_INCREMENT PRIMARY KEY,
    OrderID INT,
    ProductID INT,
    ReturnQuantity INT NOT NULL CHECK (ReturnQuantity > 0),
    Reason VARCHAR(255),
    RefundAmount DECIMAL(10,2) DEFAULT 0.00 CHECK (RefundAmount >= 0),
    ReturnDate DATE DEFAULT (CURRENT_DATE),
    ReturnStatus VARCHAR(20) DEFAULT 'Pending',
    IsRefunded TINYINT(1) DEFAULT 0,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID) ON DELETE CASCADE,
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID) ON DELETE RESTRICT
);

CREATE TABLE MaintenanceLogs (
    LogID INT AUTO_INCREMENT PRIMARY KEY,
    WarehouseID INT,
    ServiceDate DATE,
    Cost DECIMAL(10,2) CHECK (Cost >= 0),
    Technician VARCHAR(100),
    FOREIGN KEY (WarehouseID) REFERENCES Warehouses(WarehouseID) ON DELETE CASCADE
);

CREATE TABLE DiscountCoupons (
    CouponID INT AUTO_INCREMENT PRIMARY KEY,
    CouponCode VARCHAR(20) UNIQUE,
    DiscountPercent INT CHECK (DiscountPercent BETWEEN 1 AND 100),
    ExpiryDate DATE
);

-- ============================================================================
-- 2. INDEXES (PERFORMANCE OPTIMIZATION)
-- ============================================================================
CREATE INDEX idx_products_category ON Products(CategoryID);
CREATE INDEX idx_products_supplier ON Products(SupplierID);
CREATE INDEX idx_products_warehouse ON Products(WarehouseID);
CREATE INDEX idx_orders_customer ON Orders(CustomerID);
CREATE INDEX idx_orders_date ON Orders(OrderDate);
CREATE INDEX idx_orderdetails_product ON OrderDetails(ProductID);
CREATE INDEX idx_inventory_product_date ON InventoryTransactions(ProductID, TransDate);

-- ============================================================================
-- 3. TRIGGERS (FULLY FIXED FOR STOCK & TOTAL CONSISTENCY)
-- ============================================================================

DELIMITER //

-- VALIDATION TRIGGER: Prevent Negative Stock
CREATE TRIGGER trg_BeforeOrderDetailInsert
BEFORE INSERT ON OrderDetails
FOR EACH ROW
BEGIN
    DECLARE current_stock INT;

    SELECT StockQuantity INTO current_stock
    FROM Products
    WHERE ProductID = NEW.ProductID;

    IF current_stock < NEW.Quantity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Insufficient stock for this order placement';
    END IF;
END //

-- AFTER INSERT TRIGGER: Deduct Stock & Update Order Total
CREATE TRIGGER trg_AfterOrderDetailInsert
AFTER INSERT ON OrderDetails
FOR EACH ROW
BEGIN
    -- 1. Deduct Stock
    UPDATE Products
    SET StockQuantity = StockQuantity - NEW.Quantity
    WHERE ProductID = NEW.ProductID;
    
    -- 2. Log Movement
    INSERT INTO InventoryTransactions (ProductID, TransType, Quantity, ReferenceType, ReferenceID)
    VALUES (NEW.ProductID, 'OUT', NEW.Quantity, 'OrderDetails', NEW.DetailID);

    -- 3. Update Order Total
    UPDATE Orders 
    SET TotalAmount = TotalAmount + (NEW.Quantity * NEW.UnitPrice)
    WHERE OrderID = NEW.OrderID;
END //

-- AFTER UPDATE TRIGGER: Adjust stock and recalculate total
CREATE TRIGGER trg_AfterOrderDetailUpdate
AFTER UPDATE ON OrderDetails
FOR EACH ROW
BEGIN
    DECLARE new_total DECIMAL(12,2);

    -- If ProductID or Quantity changed, adjust stock levels
    IF OLD.ProductID != NEW.ProductID OR OLD.Quantity != NEW.Quantity THEN
        -- Restock old product
        UPDATE Products
        SET StockQuantity = StockQuantity + OLD.Quantity
        WHERE ProductID = OLD.ProductID;

        -- Log adjustment for old product
        INSERT INTO InventoryTransactions (ProductID, TransType, Quantity, ReferenceType, ReferenceID)
        VALUES (OLD.ProductID, 'ADJUSTMENT', OLD.Quantity, 'OrderDetails', OLD.DetailID);

        -- Deduct new product
        UPDATE Products
        SET StockQuantity = StockQuantity - NEW.Quantity
        WHERE ProductID = NEW.ProductID;

        -- Log adjustment for new product
        INSERT INTO InventoryTransactions (ProductID, TransType, Quantity, ReferenceType, ReferenceID)
        VALUES (NEW.ProductID, 'ADJUSTMENT', NEW.Quantity, 'OrderDetails', NEW.DetailID);
    END IF;

    -- Recalculate the entire order total from scratch
    SELECT COALESCE(SUM(Quantity * UnitPrice), 0) 
    INTO new_total
    FROM OrderDetails
    WHERE OrderID = NEW.OrderID;
    
    UPDATE Orders 
    SET TotalAmount = new_total
    WHERE OrderID = NEW.OrderID;
END //

-- AFTER DELETE TRIGGER: Restock and recalculate total
CREATE TRIGGER trg_AfterOrderDetailDelete
AFTER DELETE ON OrderDetails
FOR EACH ROW
BEGIN
    DECLARE new_total DECIMAL(12,2);

    -- Restock the product
    UPDATE Products
    SET StockQuantity = StockQuantity + OLD.Quantity
    WHERE ProductID = OLD.ProductID;

    -- Log adjustment
    INSERT INTO InventoryTransactions (ProductID, TransType, Quantity, ReferenceType, ReferenceID)
    VALUES (OLD.ProductID, 'ADJUSTMENT', OLD.Quantity, 'OrderDetails', OLD.DetailID);

    -- Recalculate order total
    SELECT COALESCE(SUM(Quantity * UnitPrice), 0) 
    INTO new_total
    FROM OrderDetails
    WHERE OrderID = OLD.OrderID;
    
    UPDATE Orders 
    SET TotalAmount = new_total
    WHERE OrderID = OLD.OrderID;
END //

DELIMITER ;

-- VIEW: Complete Inventory Master
CREATE VIEW vw_FullInventoryMaster AS
SELECT 
    P.ProductID,
    P.ProductName,
    COALESCE(C.CategoryName, 'Uncategorized') AS CategoryName,
    COALESCE(S.SupplierName, 'No Supplier') AS SupplierName,
    COALESCE(W.WarehouseName, 'Unassigned') AS WarehouseName,
    P.StockQuantity,
    P.MinLevel,
    P.Price
FROM Products P
LEFT JOIN Categories C ON P.CategoryID = C.CategoryID
LEFT JOIN Suppliers S ON P.SupplierID = S.SupplierID
LEFT JOIN Warehouses W ON P.WarehouseID = W.WarehouseID;

-- ============================================================================
-- 4. SAMPLE DATA (UPDATED TO RESPECT NEW CONSTRAINTS)
-- ============================================================================
INSERT INTO Regions (RegionName, TaxRate) VALUES ('Punjab', 17.5), ('Sindh', 13.0), ('KPK', 15.0), ('Balochistan', 10.0), ('Federal', 18.0);

INSERT INTO Warehouses (WarehouseName, Location, RegionID) VALUES 
('LHR-Main', 'Gulberg, Lahore', 1), ('KHI-South', 'Port Qasim, Karachi', 2), 
('ISL-Hub', 'I-9 Sector, Islamabad', 5), ('MTN-Storage', 'Vehari Road, Multan', 1), 
('FSD-Textile', 'Sargodha Road, Faisalabad', 1);

INSERT INTO Suppliers (SupplierName, ContactEmail, City, Rating) VALUES 
('Tech-Supply Co', 'contact@tech.com', 'Lahore', 5), ('Indus Goods', 'info@indus.com', 'Karachi', 4), 
('Global Importers', 'sales@global.com', 'Islamabad', 3), ('Northern Traders', 'deals@north.com', 'Peshawar', 4), 
('Southern Logistics', 'admin@south.com', 'Quetta', 5), ('Prime Build', 'prime@build.com', 'Sialkot', 4), 
('Star Hardware', 'star@hw.com', 'Lahore', 3);

INSERT INTO Categories (CategoryName, ShelfLifeDays) VALUES 
('Electronics', 730), ('Perishables', 7), ('Furniture', 3650), 
('Tools', 1825), ('Apparel', 1000), ('Kitchenware', 2000);

INSERT INTO Employees (EmpName, JobTitle, Salary, WarehouseID) VALUES 
('Ahmed Raza', 'Manager', 95000, 1), ('Sara Khan', 'Supervisor', 55000, 1), 
('Ali Hamza', 'Worker', 35000, 1), ('Zaid Siddiqui', 'Manager', 92000, 2), 
('Hina Altaf', 'Staff', 40000, 2), ('Bilal Shah', 'Staff', 42000, 3), 
('Usman Jan', 'Manager', 88000, 4), ('Fatima Noor', 'Analyst', 60000, 3);

INSERT INTO Products (ProductName, Price, CategoryID, SupplierID, WarehouseID, StockQuantity, MinLevel) VALUES 
('Macbook Pro', 350000.00, 1, 1, 1, 50, 5), ('Logitech Mouse', 4500.00, 1, 1, 1, 200, 20), 
('Office Chair', 15000.00, 3, 2, 1, 30, 5), ('Dining Table', 45000.00, 3, 2, 4, 10, 2), 
('Drill Kit', 12000.00, 4, 6, 3, 100, 10), ('Leather Jacket', 8000.00, 5, 4, 2, 60, 15), 
('LED Monitor', 25000.00, 1, 3, 3, 40, 8), ('Mechanical Keyboard', 9000.00, 1, 7, 1, 85, 10), 
('Gaming PC', 150000.00, 1, 1, 3, 12, 3), ('Hammer', 1200.00, 4, 7, 4, 500, 50), 
('Smartphone', 65000.00, 1, 1, 2, 150, 25), ('Sofa Set', 120000.00, 3, 3, 4, 5, 2), 
('Webcam HD', 5500.00, 1, 1, 1, 70, 10), ('USB-C Hub', 3200.00, 1, 7, 1, 120, 15), 
('Desk Lamp LED', 4200.00, 3, 2, 4, 45, 5);

INSERT INTO Customers (CustomerName, Phone, City, IsPremium) VALUES 
('Umer Farooq', '0300-1112223', 'Lahore', 1), ('Ayesha Malik', '0321-4445556', 'Karachi', 0), 
('Hassan Ali', '0312-7778889', 'Islamabad', 1), ('Marium Bibi', '0333-0009991', 'Faisalabad', 0), 
('Zain Raza', '0345-2223334', 'Quetta', 0), ('Kashif Jamil', '0311-6663332', 'Sialkot', 1), 
('Sana Ullah', '0302-8881110', 'Multan', 0);

INSERT INTO Orders (CustomerID, EmployeeID, OrderDate, OrderStatus) VALUES 
(1, 1, '2026-01-10', 'Completed'), (2, 4, '2026-01-12', 'Completed'), 
(3, 2, '2026-01-15', 'Completed'), (4, 3, '2026-01-20', 'Completed'), 
(5, 5, '2026-01-25', 'Completed'), (1, 6, '2026-02-01', 'Completed'), 
(6, 7, '2026-02-05', 'Pending');

-- These inserts will automatically calculate TotalAmount via the triggers
INSERT INTO OrderDetails (OrderID, ProductID, Quantity, UnitPrice) VALUES 
(1, 1, 1, 350000.00), (1, 2, 1, 4500.00), (2, 3, 1, 15000.00), 
(3, 5, 2, 12000.00), (4, 12, 1, 120000.00), (5, 8, 1, 9000.00), 
(6, 7, 2, 25000.00), (7, 10, 1, 1200.00);

INSERT INTO Payments (OrderID, PaymentMode, AmountPaid, PaymentDate) VALUES 
(1, 'Credit Card', 354500.00, '2026-01-10'), (2, 'Cash', 15000.00, '2026-01-12'), 
(3, 'Bank Transfer', 24000.00, '2026-01-15'), (4, 'Credit Card', 120000.00, '2026-01-20'), 
(5, 'EasyPaisa', 9000.00, '2026-01-25'), (6, 'JazzCash', 50000.00, '2026-02-01');

-- Shipments: 'Pending' changed to 'Processing' to match the new CHECK constraint
INSERT INTO Shipments (OrderID, Carrier, TrackingNumber, ShipDate, Status) VALUES 
(1, 'TCS', 'TRK1001', '2026-01-11', 'Delivered'),
(2, 'Leopard', 'TRK1002', '2026-01-13', 'Delivered'),
(3, 'DHL', 'TRK1003', '2026-01-16', 'In Transit'),
(4, 'Bykea', 'TRK1004', '2026-01-21', 'Processing');

INSERT INTO ProductReturns (OrderID, ProductID, ReturnQuantity, Reason, RefundAmount, IsRefunded) VALUES 
(1, 2, 1, 'Defective Scroll Wheel', 4500.00, 1), (3, 5, 1, 'Damaged Box', 0.00, 0);

-- ============================================================================
-- 5. COMPLETE 15-RESULT ANALYTICAL & REPORTING SUITE
-- ============================================================================

-- Result 1: Master Inventory View
SELECT '1. Master Inventory' AS Report_Type, V.* 
FROM vw_FullInventoryMaster V;

-- Result 2: Regional Tax Rates & Valuation
SELECT 
    '2. Regional Valuation' AS Report_Type,
    R.RegionName,
    R.TaxRate,
    COUNT(W.WarehouseID) AS TotalWarehouses
FROM Regions R
LEFT JOIN Warehouses W ON R.RegionID = W.RegionID
GROUP BY R.RegionID, R.RegionName, R.TaxRate;

-- Result 3: Warehouse Stock & Inventory Valuation
SELECT 
    '3. Warehouse Stock' AS Report_Type,
    W.WarehouseName,
    COUNT(DISTINCT P.ProductID) AS TotalProductsStored,
    SUM(P.StockQuantity) AS TotalStockUnits,
    SUM(P.Price * P.StockQuantity) AS TotalInventoryValue
FROM Warehouses W
LEFT JOIN Products P ON W.WarehouseID = P.WarehouseID
GROUP BY W.WarehouseID, W.WarehouseName;

-- Result 4: Supplier Performance & Ratings
SELECT 
    '4. Supplier Performance' AS Report_Type,
    S.SupplierName,
    S.Rating,
    COUNT(DISTINCT P.ProductID) AS ProductsSupplied,
    SUM(P.StockQuantity) AS CurrentStockOnHand
FROM Suppliers S
LEFT JOIN Products P ON S.SupplierID = P.SupplierID
GROUP BY S.SupplierID, S.SupplierName, S.Rating
ORDER BY S.Rating DESC;

-- Result 5: Category Performance & Ranking (Window Function)
SELECT 
    '5. Category Ranking' AS Report_Type,
    C.CategoryName,
    P.ProductName,
    SUM(OD.Quantity) AS TotalSold,
    RANK() OVER (PARTITION BY C.CategoryName ORDER BY SUM(OD.Quantity) DESC) AS CategoryRank
FROM OrderDetails OD
INNER JOIN Products P ON OD.ProductID = P.ProductID
INNER JOIN Categories C ON P.CategoryID = C.CategoryID
GROUP BY C.CategoryName, P.ProductName, P.ProductID;

-- Result 6: Product Low-Stock Reorder Priority List
SELECT 
    '6. Low-Stock Alert' AS Report_Type,
    P.ProductName,
    W.WarehouseName,
    P.StockQuantity,
    P.MinLevel,
    (P.MinLevel - P.StockQuantity) AS UnitsNeededToReorder
FROM Products P
LEFT JOIN Warehouses W ON P.WarehouseID = W.WarehouseID
WHERE P.StockQuantity <= P.MinLevel
ORDER BY UnitsNeededToReorder DESC;

-- Result 7: Employee Sales Performance
SELECT 
    '7. Employee Sales' AS Report_Type,
    E.EmpName,
    E.JobTitle,
    COUNT(O.OrderID) AS TotalOrdersProcessed,
    COALESCE(SUM(O.TotalAmount), 0) AS RevenueHandled
FROM Employees E
LEFT JOIN Orders O ON E.EmployeeID = O.EmployeeID
GROUP BY E.EmployeeID, E.EmpName, E.JobTitle
ORDER BY RevenueHandled DESC;

-- Result 8: Premium Customer Lifetime Value (CTE)
WITH CustomerLTV AS (
    SELECT 
        C.CustomerName,
        C.City,
        COUNT(O.OrderID) AS TotalOrders,
        SUM(O.TotalAmount) AS LifetimeValue
    FROM Customers C
    INNER JOIN Orders O ON C.CustomerID = O.CustomerID
    WHERE C.IsPremium = 1
    GROUP BY C.CustomerName, C.City
)
SELECT '8. Customer LTV' AS Report_Type, LTV.* 
FROM CustomerLTV LTV 
ORDER BY LifetimeValue DESC;

-- Result 9: Order Payment & Outstanding Balance Audit
SELECT 
    '9. Payment Audit' AS Report_Type,
    O.OrderID,
    O.TotalAmount,
    COALESCE(SUM(P.AmountPaid), 0) AS PaidAmount,
    (O.TotalAmount - COALESCE(SUM(P.AmountPaid), 0)) AS OutstandingBalance,
    O.OrderStatus
FROM Orders O
LEFT JOIN Payments P ON O.OrderID = P.OrderID
GROUP BY O.OrderID, O.TotalAmount, O.OrderStatus;

-- Result 10: Top Selling Products by Revenue
SELECT 
    '10. Top Selling Products' AS Report_Type,
    P.ProductName,
    SUM(OD.Quantity) AS UnitsSold,
    SUM(OD.Quantity * OD.UnitPrice) AS TotalRevenueGenerated
FROM OrderDetails OD
JOIN Products P ON OD.ProductID = P.ProductID
GROUP BY P.ProductID, P.ProductName
ORDER BY TotalRevenueGenerated DESC;

-- Result 11: Inventory Transaction History Log
SELECT 
    '11. Transaction Log' AS Report_Type,
    IT.TransactionID,
    P.ProductName,
    IT.TransType,
    IT.Quantity,
    IT.ReferenceType,
    IT.TransDate
FROM InventoryTransactions IT
JOIN Products P ON IT.ProductID = P.ProductID
ORDER BY IT.TransDate DESC;

-- Result 12: Payment Modes Summary
SELECT 
    '12. Payment Modes' AS Report_Type,
    PaymentMode,
    COUNT(PaymentID) AS TotalTransactions,
    SUM(AmountPaid) AS TotalAmountCollected
FROM Payments
GROUP BY PaymentMode;

-- Result 13: Carrier & Shipment Status Breakdown
SELECT 
    '13. Shipment Status' AS Report_Type,
    Carrier,
    Status,
    COUNT(ShipmentID) AS TotalShipments
FROM Shipments
GROUP BY Carrier, Status;

-- Result 14: Product Return Rate & Refund Audit
SELECT 
    '14. Return & Refund Audit' AS Report_Type,
    P.ProductName,
    COUNT(PR.ReturnID) AS TotalReturns,
    SUM(PR.ReturnQuantity) AS TotalUnitsReturned,
    SUM(PR.RefundAmount) AS TotalRefundedAmount
FROM ProductReturns PR
JOIN Products P ON PR.ProductID = P.ProductID
GROUP BY P.ProductID, P.ProductName;

-- Result 15: Monthly Revenue Trend & MoM Comparison (CTE & Lag)
WITH MonthlyMetrics AS (
    SELECT 
        DATE_FORMAT(OrderDate, '%Y-%m') AS OrderMonth,
        COUNT(OrderID) AS OrderCount,
        SUM(TotalAmount) AS Revenue
    FROM Orders
    GROUP BY DATE_FORMAT(OrderDate, '%Y-%m')
)
SELECT 
    '15. Monthly Trend' AS Report_Type,
    OrderMonth, 
    OrderCount, 
    Revenue,
    LAG(Revenue) OVER (ORDER BY OrderMonth) AS PrevMonthRevenue
FROM MonthlyMetrics;

-- Force Macbook Pro stock below its minimum level (MinLevel is 5)
UPDATE Products 
SET StockQuantity = 3 
WHERE ProductID = 1;

-- END OF SCRIPT