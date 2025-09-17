IF OBJECT_ID('dev.dbo.Products', 'U') IS NOT NULL DROP TABLE dev.dbo.Products;
CREATE TABLE dev.dbo.Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductCode NVARCHAR(50) NOT NULL UNIQUE,
    ProductName NVARCHAR(255),
    CategoryID INT NULL FOREIGN KEY REFERENCES dev.dbo.Categories(CategoryID)
);

WITH RankedProducts AS (
  SELECT
    Product AS ProductCode,
    ProductName,
    c.CategoryID,
    ROW_NUMBER() OVER (PARTITION BY Product, c.CategoryID ORDER BY LEN(ProductName) DESC) as rn
  FROM dev.dbo.StagingOrders s
  LEFT JOIN dev.dbo.Categories c
    ON s.Level1Category = c.Level1Category
)
INSERT INTO dev.dbo.Products (ProductCode, ProductName, CategoryID)
SELECT DISTINCT
  ProductCode,
  ProductName,
  CategoryID
FROM RankedProducts
WHERE rn = 1;