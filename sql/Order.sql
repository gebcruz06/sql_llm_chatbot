IF OBJECT_ID('dev.dbo.[Order]', 'U') IS NOT NULL DROP TABLE dev.dbo.[Order];
CREATE TABLE dev.dbo.[Order] (
    OrderID NVARCHAR(50) PRIMARY KEY,
    OrderTotalQuantity INT,
    OrderTotalPrice DECIMAL(18,4),
    OrderTotalTax DECIMAL(18,4),
    OrderTotalInc DECIMAL(18,4),
    CreationDate DATETIME2
);

INSERT INTO dev.dbo.[Order] 
    (OrderID, OrderTotalQuantity, OrderTotalPrice, OrderTotalTax, OrderTotalInc, CreationDate)
SELECT DISTINCT
    s.InchcapeOrderNo as OrderID,
    sum(TRY_CONVERT(INT, s.Quantity)) as OrderTotalQuantity,
    OrderTotalPrice,
    s.OrderTotalTax,
    s.OrderTotalInc,
    s.CreationDate
FROM dev.stg.RawOrder s
GROUP BY
    s.InchcapeOrderNo,
    OrderTotalPrice,
    s.OrderTotalTax,
    s.OrderTotalInc,
    s.CreationDate