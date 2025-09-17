IF OBJECT_ID('dev.dbo.Sellers', 'U') IS NOT NULL DROP TABLE dev.dbo.Sellers;
CREATE TABLE dev.dbo.Sellers (
    SellerID INT IDENTITY(1,1) PRIMARY KEY,
    SellerAccountNo NVARCHAR(50) NOT NULL UNIQUE,
    SellerTradingName NVARCHAR(255),
    Site NVARCHAR(100)
);

INSERT INTO dev.dbo.Sellers (SellerAccountNo, SellerTradingName, Site)
SELECT DISTINCT
    SellerAccountNo,
    SellerTradingName,
    site
FROM dev.dbo.StagingOrders
WHERE SellerAccountNo IS NOT NULL;