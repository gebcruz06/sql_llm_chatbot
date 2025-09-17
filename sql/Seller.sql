IF OBJECT_ID('dev.dbo.Seller', 'U') IS NOT NULL DROP TABLE dev.dbo.Seller;
CREATE TABLE dev.dbo.Seller (
    SellerID INT IDENTITY(1,1) PRIMARY KEY,
    SellerAccountNo NVARCHAR(50) NOT NULL UNIQUE,
    SellerTradingName NVARCHAR(255),
    Site NVARCHAR(100)
);

INSERT INTO dev.dbo.Seller (SellerAccountNo, SellerTradingName, Site)
SELECT DISTINCT
    SellerAccountNo,
    SellerTradingName,
    site
FROM dev.stg.RawOrder
WHERE SellerAccountNo IS NOT NULL;