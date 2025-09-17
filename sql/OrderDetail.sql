IF OBJECT_ID('dev.dbo.OrderDetail', 'U') IS NOT NULL DROP TABLE dev.dbo.OrderDetail;
CREATE TABLE dev.dbo.OrderDetail (
    OrderDetailID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID NVARCHAR(50) NOT NULL FOREIGN KEY REFERENCES dev.dbo.[Order](OrderID),
    BuyerID INT NOT NULL FOREIGN KEY REFERENCES dev.dbo.Buyer(BuyerID),
    SellerID INT NOT NULL FOREIGN KEY REFERENCES dev.dbo.Seller(SellerID),
    UserID INT NULL FOREIGN KEY REFERENCES dev.dbo.[User](UserID),
    ProductID INT NOT NULL FOREIGN KEY REFERENCES dev.dbo.[Product](ProductID),
    Currency NVARCHAR(10),
    Country NVARCHAR(100),
    SellerInvoiceNo NVARCHAR(50),
    BuyerPurchaseOrderNo NVARCHAR(50),
    OrderStatus NVARCHAR(50),
    OrderStatusDesc NVARCHAR(255),
    CancelledFlag BIT,
    Quantity INT,
    ProductUnitPrice DECIMAL(18,4),
    ProductTotalPrice DECIMAL(18,4)
);

INSERT INTO dev.dbo.OrderDetail 
    (OrderID, BuyerID, SellerID, UserID, ProductID, Currency, Country, SellerInvoiceNo, BuyerPurchaseOrderNo, 
     OrderStatus, OrderStatusDesc, CancelledFlag, Quantity, ProductUnitPrice, ProductTotalPrice)
SELECT DISTINCT
    s.InchcapeOrderNo as OrderID
    ,b.BuyerID,
    se.SellerID,
    u.UserID,
    p.ProductID,
    s.currency,
    s.country,
    s.SellerInvoiceNo,
    s.BuyerPurchaseOrderNo,
    s.OrderStatus,
    s.OrderStatusDesc,
    CASE WHEN s.CancelledFlag IS NULL THEN 0 ELSE 1 END as CancelledFlag,
    s.Quantity,
    s.ProductUnitPrice,
    s.ProductTotalPrice
FROM dev.stg.RawOrder s
JOIN dev.dbo.Buyer b ON s.BuyerAccountNo = b.BuyerAccountNo
JOIN dev.dbo.Seller se ON s.SellerAccountNo = se.SellerAccountNo
JOIN dev.dbo.[User] u ON s.users = u.Username
JOIN dev.dbo.[Product] p ON s.Product = p.ProductCode;