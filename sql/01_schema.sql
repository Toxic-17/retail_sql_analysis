-- ============================================================
-- SQL-Based Retail Data Analysis — Database Schema
-- Engine: MySQL 8.0+ (InnoDB, utf8mb4)
--
-- A normalized, relational (3NF) retail schema — distinct in purpose
-- from a BI star schema: this models the actual transactional system
-- (customers placing orders containing line items for products sold
-- across stores) that a retail business's order-management system
-- would run on, which is then queried directly for analysis.
-- ============================================================

DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS stores;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id   INT PRIMARY KEY,
    first_name    VARCHAR(50)  NOT NULL,
    last_name     VARCHAR(50)  NOT NULL,
    email         VARCHAR(120) NOT NULL,
    city          VARCHAR(60),
    state         VARCHAR(60),
    region        VARCHAR(30),
    signup_date   DATE NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE categories (
    category_id    INT PRIMARY KEY,
    category_name  VARCHAR(60) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE products (
    product_id    INT PRIMARY KEY,
    product_name  VARCHAR(100) NOT NULL,
    category_id   INT NOT NULL,
    unit_price    DECIMAL(10,2) NOT NULL,
    unit_cost     DECIMAL(10,2) NOT NULL,
    launch_date   DATE,
    CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES categories(category_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE stores (
    store_id    INT PRIMARY KEY,
    store_name  VARCHAR(100) NOT NULL,
    city        VARCHAR(60),
    state       VARCHAR(60),
    region      VARCHAR(30)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE orders (
    order_id        INT PRIMARY KEY,
    customer_id     INT NOT NULL,
    store_id        INT NOT NULL,
    order_date      DATETIME NOT NULL,
    payment_method  VARCHAR(30) NOT NULL,
    order_status    VARCHAR(20) NOT NULL,
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_orders_store FOREIGN KEY (store_id) REFERENCES stores(store_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE order_items (
    order_item_id  INT PRIMARY KEY,
    order_id       INT NOT NULL,
    product_id     INT NOT NULL,
    quantity       INT NOT NULL,
    unit_price     DECIMAL(10,2) NOT NULL,
    discount_pct   TINYINT NOT NULL DEFAULT 0,
    CONSTRAINT fk_items_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products(product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Note: deliberately NOT indexing order_date, order_status, customer.email,
-- or the composite (store_id, order_date) yet — see 06_query_optimization.sql,
-- which measures real query performance before and after adding exactly
-- these indexes.
