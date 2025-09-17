IF OBJECT_ID('dev.dbo.Categories', 'U') IS NOT NULL DROP TABLE dev.dbo.Categories;
CREATE TABLE dev.dbo.Categories (
    CategoryID INT IDENTITY(1,1) PRIMARY KEY,
    Level1Category NVARCHAR(255) NOT NULL UNIQUE
);

INSERT INTO dev.dbo.Categories (Level1Category)
SELECT DISTINCT Level1Category
FROM dev.dbo.StagingOrders
WHERE Level1Category IS NOT NULL;