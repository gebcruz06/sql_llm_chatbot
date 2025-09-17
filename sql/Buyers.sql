IF OBJECT_ID('dev.dbo.Buyers', 'U') IS NOT NULL DROP TABLE dev.dbo.Buyers;
CREATE TABLE dev.dbo.Buyers (
    BuyerID INT IDENTITY(1,1) PRIMARY KEY,
    BuyerAccountNo NVARCHAR(50) NOT NULL UNIQUE,
    BuyerTradingName NVARCHAR(255)
);

INSERT INTO dev.dbo.Buyers (BuyerAccountNo, BuyerTradingName)
SELECT DISTINCT
    BuyerAccountNo,
    BuyerTradingName
FROM dev.dbo.StagingOrders
WHERE BuyerAccountNo IS NOT NULL;