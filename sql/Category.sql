IF OBJECT_ID('dev.dbo.Category', 'U') IS NOT NULL DROP TABLE dev.dbo.Category;
CREATE TABLE dev.dbo.Category (
    CategoryID INT IDENTITY(1,1) PRIMARY KEY,
    Level1Category NVARCHAR(255) NOT NULL UNIQUE
);

INSERT INTO dev.dbo.Category (Level1Category)
SELECT DISTINCT Level1Category
FROM dev.stg.RawOrder
WHERE Level1Category IS NOT NULL;