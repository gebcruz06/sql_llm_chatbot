IF OBJECT_ID('dev.dbo.Buyer', 'U') IS NOT NULL DROP TABLE dev.dbo.Buyer;
CREATE TABLE dev.dbo.Buyer (
    BuyerID INT IDENTITY(1,1) PRIMARY KEY,
    BuyerAccountNo NVARCHAR(50) NOT NULL UNIQUE,
    BuyerTradingName NVARCHAR(255)
);

INSERT INTO dev.dbo.Buyer (BuyerAccountNo, BuyerTradingName)
SELECT DISTINCT
    BuyerAccountNo,
    BuyerTradingName
FROM dev.stg.RawOrder
WHERE BuyerAccountNo IS NOT NULL;