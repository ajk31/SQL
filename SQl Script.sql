/* =========================================================
   FOOD WASTE REDUCTION SYSTEM – UK SUPERMARKETS
   Relational Database Prototype
   ========================================================= */

-- Create database
CREATE DATABASE food_waste_db;
USE food_waste_db;

-- =========================================================
-- 1. CORE TABLES
-- =========================================================

CREATE TABLE Store (
    store_id INT AUTO_INCREMENT PRIMARY KEY,
    store_name VARCHAR(100) NOT NULL,
    location VARCHAR(150) NOT NULL,
    manager_name VARCHAR(100),
    UNIQUE(store_name, location)
);

CREATE TABLE Supplier (
    supplier_id INT AUTO_INCREMENT PRIMARY KEY,
    supplier_name VARCHAR(150) NOT NULL,
    contact_email VARCHAR(150),
    contact_phone VARCHAR(20),
    UNIQUE(supplier_name)
);

CREATE TABLE Product_Category (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE Product (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(150) NOT NULL,
    category_id INT NOT NULL,
    supplier_id INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    shelf_life_days INT NOT NULL,
    FOREIGN KEY (category_id) REFERENCES Product_Category(category_id),
    FOREIGN KEY (supplier_id) REFERENCES Supplier(supplier_id)
);

CREATE TABLE Inventory (
    inventory_id INT AUTO_INCREMENT PRIMARY KEY,
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    batch_number VARCHAR(50) NOT NULL,
    quantity_in_stock INT NOT NULL CHECK (quantity_in_stock >= 0),
    expiry_date DATE NOT NULL,
    delivery_date DATE NOT NULL,
    FOREIGN KEY (store_id) REFERENCES Store(store_id),
    FOREIGN KEY (product_id) REFERENCES Product(product_id),
    UNIQUE(store_id, product_id, batch_number)
);

CREATE TABLE Sales (
    sale_id INT AUTO_INCREMENT PRIMARY KEY,
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity_sold INT NOT NULL CHECK (quantity_sold > 0),
    sale_date DATE NOT NULL,
    FOREIGN KEY (store_id) REFERENCES Store(store_id),
    FOREIGN KEY (product_id) REFERENCES Product(product_id)
);

CREATE TABLE Waste_Reason (
    reason_id INT AUTO_INCREMENT PRIMARY KEY,
    reason_description VARCHAR(150) NOT NULL UNIQUE
);

CREATE TABLE Waste_Record (
    waste_id INT AUTO_INCREMENT PRIMARY KEY,
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    reason_id INT NOT NULL,
    quantity_wasted INT NOT NULL CHECK (quantity_wasted > 0),
    waste_date DATE NOT NULL,
    FOREIGN KEY (store_id) REFERENCES Store(store_id),
    FOREIGN KEY (product_id) REFERENCES Product(product_id),
    FOREIGN KEY (reason_id) REFERENCES Waste_Reason(reason_id)
);

CREATE TABLE Discount_Action (
    discount_id INT AUTO_INCREMENT PRIMARY KEY,
    inventory_id INT NOT NULL,
    discount_percentage DECIMAL(5,2) NOT NULL CHECK (discount_percentage BETWEEN 0 AND 100),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    FOREIGN KEY (inventory_id) REFERENCES Inventory(inventory_id)
);

CREATE TABLE Donation_Record (
    donation_id INT AUTO_INCREMENT PRIMARY KEY,
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    charity_name VARCHAR(150) NOT NULL,
    quantity_donated INT NOT NULL CHECK (quantity_donated > 0),
    donation_date DATE NOT NULL,
    FOREIGN KEY (store_id) REFERENCES Store(store_id),
    FOREIGN KEY (product_id) REFERENCES Product(product_id)
);

-- =========================================================
-- 2. INDEXES FOR PERFORMANCE
-- =========================================================

CREATE INDEX idx_inventory_expiry ON Inventory(expiry_date);
CREATE INDEX idx_sales_date ON Sales(sale_date);
CREATE INDEX idx_waste_date ON Waste_Record(waste_date);

-- =========================================================
-- 3. SAMPLE DATA
-- =========================================================

INSERT INTO Store (store_name, location, manager_name)
VALUES ('Tesco Express', 'London', 'James Carter'),
       ('Sainsbury Central', 'Manchester', 'Sarah Ahmed');

INSERT INTO Supplier (supplier_name, contact_email)
VALUES ('FreshFarm Ltd', 'contact@freshfarm.co.uk'),
       ('GreenHarvest Co', 'info@greenharvest.co.uk');

INSERT INTO Product_Category (category_name)
VALUES ('Dairy'), ('Bakery'), ('Produce');

INSERT INTO Product (product_name, category_id, supplier_id, unit_price, shelf_life_days)
VALUES ('Milk 2L', 1, 1, 1.50, 7),
       ('Wholemeal Bread', 2, 2, 1.20, 3),
       ('Apples 1kg', 3, 1, 2.00, 10);

INSERT INTO Inventory (store_id, product_id, batch_number, quantity_in_stock, expiry_date, delivery_date)
VALUES (1, 1, 'BATCH001', 200, '2026-03-10', '2026-03-01'),
       (1, 2, 'BATCH002', 150, '2026-03-05', '2026-03-02'),
       (2, 3, 'BATCH003', 300, '2026-03-15', '2026-03-01');

INSERT INTO waste_record (store_id, product_id, reason_id, quantity_wasted, waste_date)
VALUES
(1, 1, 1, 25, '2026-03-01'),
(1, 2, 1, 15, '2026-03-02'),
(1, 1, 3, 10, '2026-03-03'),
(2, 3, 2, 30, '2026-03-02'),
(2, 3, 1, 20, '2026-03-04');

INSERT INTO Waste_Reason (reason_description)
VALUES ('Expired'), ('Damaged Packaging'), ('Overstocking');

-- =========================================================
-- 4. CRUD OPERATIONS
-- =========================================================

-- CREATE (record sale)
INSERT INTO Sales (store_id, product_id, quantity_sold, sale_date)
VALUES (1, 1, 20, CURDATE());

-- READ (products nearing expiry within 3 days)
SELECT p.product_name, i.expiry_date, i.quantity_in_stock
FROM Inventory i
JOIN Product p ON i.product_id = p.product_id
WHERE DATEDIFF(i.expiry_date, CURDATE()) <= 3;

-- UPDATE (apply discount)
UPDATE Inventory
SET quantity_in_stock = quantity_in_stock - 10
WHERE inventory_id = 1;

-- DELETE (remove discontinued product)
DELETE FROM Product WHERE product_id = 99;

-- =========================================================
-- 5. ANALYTICAL QUERIES
-- =========================================================

-- Waste per product
SELECT p.product_name,
       SUM(w.quantity_wasted) AS total_waste
FROM Waste_Record w
JOIN Product p ON w.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_waste DESC;

-- Waste percentage per store
SELECT s.store_name,
       SUM(w.quantity_wasted) AS total_waste,
       SUM(sa.quantity_sold) AS total_sold,
       (SUM(w.quantity_wasted) / 
       (SUM(w.quantity_wasted) + SUM(sa.quantity_sold))) * 100 AS waste_percentage
FROM Store s
LEFT JOIN Waste_Record w ON s.store_id = w.store_id
LEFT JOIN Sales sa ON s.store_id = sa.store_id
GROUP BY s.store_name;

-- =========================================================
-- 6. VIEW FOR DECISION SUPPORT
-- =========================================================

CREATE VIEW High_Risk_Products AS
SELECT p.product_name,
       SUM(w.quantity_wasted) AS total_waste
FROM Waste_Record w
JOIN Product p ON w.product_id = p.product_id
GROUP BY p.product_name
HAVING total_waste > 50;

-- =========================================================
-- 7. STORED PROCEDURE FOR WASTE SUMMARY
-- =========================================================

DELIMITER $$

CREATE PROCEDURE GetStoreWaste(IN storeId INT)
BEGIN
    SELECT s.store_name,
           p.product_name,
           SUM(w.quantity_wasted) AS total_waste
    FROM Waste_Record w
    JOIN Product p ON w.product_id = p.product_id
    JOIN Store s ON w.store_id = s.store_id
    WHERE s.store_id = storeId
    GROUP BY p.product_name;
END $$

DELIMITER ;

-- =========================================================
-- END OF SCRIPT
-- =========================================================