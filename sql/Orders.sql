IF OBJECT_ID('dev.dbo.Orders', 'U') IS NOT NULL DROP TABLE dev.dbo.Orders;
CREATE TABLE dev.dbo.Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    InchcapeOrderNo NVARCHAR(50) NOT NULL UNIQUE,
    BuyerID INT NOT NULL FOREIGN KEY REFERENCES dev.dbo.Buyers(BuyerID),
    SellerID INT NOT NULL FOREIGN KEY REFERENCES dev.dbo.Sellers(SellerID),
    UserID INT NULL FOREIGN KEY REFERENCES dev.dbo.Users(UserID),
    Currency NVARCHAR(10),
    Country NVARCHAR(100),
    CreationDate DATETIME2,
    SellerInvoiceNo NVARCHAR(50),
    BuyerPurchaseOrderNo NVARCHAR(50),
    OrderStatus NVARCHAR(50),
    OrderStatusDesc NVARCHAR(255),
    CancelledFlag BIT,
    OrderTotalPrice DECIMAL(18,4),
    OrderTotalTax DECIMAL(18,4),
    OrderTotalInc DECIMAL(18,4)
);


WITH LatestOrders AS (
    SELECT
        s.InchcapeOrderNo,
        b.BuyerID,
        sel.SellerID,
        u.UserID,
        s.currency,
        s.country,
        s.CreationDate,
        s.SellerInvoiceNo,
        s.BuyerPurchaseOrderNo,
        s.OrderStatus,
        s.OrderStatusDesc,
        CASE WHEN s.CancelledFlag IS NULL OR s.CancelledFlag = '' THEN 0 ELSE 1 END AS CancelledFlag,
        s.OrderTotalPrice,
        s.OrderTotalTax,
        s.OrderTotalInc,
        ROW_NUMBER() OVER (
            PARTITION BY
                s.InchcapeOrderNo
            ORDER BY
                s.CreationDate DESC
        ) AS rn
    FROM
        dev.dbo.StagingOrders s
    JOIN
        dev.dbo.Buyers b ON s.BuyerAccountNo = b.BuyerAccountNo
    JOIN
        dev.dbo.Sellers sel ON s.SellerAccountNo = sel.SellerAccountNo
    LEFT JOIN
        dev.dbo.Users u ON s.users = u.Username
)

INSERT INTO dev.dbo.Orders (
    InchcapeOrderNo, BuyerID, SellerID, UserID,
    Currency, Country, CreationDate, SellerInvoiceNo,
    BuyerPurchaseOrderNo, OrderStatus, OrderStatusDesc,
    CancelledFlag, OrderTotalPrice, OrderTotalTax, OrderTotalInc
)
SELECT
    InchcapeOrderNo,
    BuyerID,
    SellerID,
    UserID,
    currency,
    country,
    CreationDate,
    SellerInvoiceNo,
    BuyerPurchaseOrderNo,
    OrderStatus,
    OrderStatusDesc,
    CancelledFlag,
    OrderTotalPrice,
    OrderTotalTax,
    OrderTotalInc
FROM
    LatestOrders
WHERE
    rn = 1;