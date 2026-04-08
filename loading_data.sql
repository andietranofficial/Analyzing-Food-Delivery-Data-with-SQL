/*

-- In PowerShell, run the following commands to download the CSV files to your local machine:
Test-Path "C:\Users\AndieTran\Delivr"


Invoke-WebRequest -Uri "https://assets.datacamp.com/production/repositories/4016/datasets/732c094b30a2e794d0b12b12547587a903126f68/meals.csv" -OutFile 'C:\Users\AndieTran\Delivr\meals.csv'
Invoke-WebRequest -Uri "https://assets.datacamp.com/production/repositories/4016/datasets/606e6e9165c25477db078996fa7e0a3e994b93d3/orders.csv" -OutFile 'C:\Users\AndieTran\Delivr\orders.csv'
Invoke-WebRequest -Uri "https://assets.datacamp.com/production/repositories/4016/datasets/10d9ad146a85010d836cfc93870aa464951f0640/stock.csv" -OutFile 'C:\Users\AndieTran\Delivr\stock.csv'

*/

-- create master key once
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Your-Password-Here!'; -- change this to a strong password and keep it secure

-- create credential for Azure Blob Storage access
CREATE DATABASE SCOPED CREDENTIAL MyCred
WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
SECRET = 'sv=...'; --generate SAS token in a short period of time for security reasons

-- verify it exists
SELECT name
FROM sys.database_scoped_credentials;

-- create external data source for Azure Blob Storage
CREATE EXTERNAL DATA SOURCE MyBlobStorage
WITH (
    TYPE = BLOB_STORAGE,
    LOCATION = 'https://<storage-account>.blob.core.windows.net/<container>',
    CREDENTIAL = MyCred
);

-- create schemas
CREATE SCHEMA delivery;
GO

DROP TABLE IF EXISTS delivery.meals;
CREATE TABLE delivery.meals (
  meal_id INT,
  eatery NVARCHAR(255),  -- Changed TEXT to NVARCHAR for SQL Server
  meal_price FLOAT,
  meal_cost FLOAT
);

DROP TABLE IF EXISTS delivery.orders;
CREATE TABLE delivery.orders (
  order_date DATE,
  user_id INT,
  order_id INT,
  meal_id INT,
  order_quantity INT
);

DROP TABLE IF EXISTS delivery.stock_stage;
CREATE TABLE delivery.stock_stage (
  stocking_date NVARCHAR(255), -- convert column type later to DATE after loading data
  meal_id INT,
  stocked_quantity INT
);

DROP TABLE IF EXISTS delivery.stock;
CREATE TABLE delivery.stock (
  stocking_date DATE, 
  meal_id INT,
  stocked_quantity INT
);

-- Load data using BULK INSERT 
BULK INSERT delivery.meals
FROM 'meals.csv'  
WITH (
    DATA_SOURCE = 'MyBlobStorage',
    FORMAT = 'CSV',
    FIRSTROW = 2, -- Skip header row
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a'
);

BULK INSERT delivery.orders
FROM 'orders.csv'  
WITH (
    DATA_SOURCE = 'MyBlobStorage',
    FORMAT = 'CSV',
    FIRSTROW = 2, -- Skip header row
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a'
);

BULK INSERT delivery.stock_stage
FROM 'stock.csv'  
WITH (
    DATA_SOURCE = 'MyBlobStorage',
    FORMAT = 'CSV',
    FIRSTROW = 2, -- Skip header row
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a'
);

-- Convert stocking_date to DATE format and insert into final stock table
INSERT INTO delivery.stock (stocking_date, meal_id, stocked_quantity)

SELECT 
    TRY_CAST(stocking_date AS DATE) AS stocking_date, 
    meal_id, 
    stocked_quantity
FROM delivery.stock_stage;

-- Check for any rows that failed to convert to DATE format
SELECT *
FROM delivery.stock_stage
WHERE TRY_CONVERT(date, stocking_date, 103) IS NULL;

-- Clean up staging table
DROP TABLE delivery.stock_stage;
