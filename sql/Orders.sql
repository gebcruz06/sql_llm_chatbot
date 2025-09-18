IF OBJECT_ID('dev.dbo.Orders', 'U') IS NOT NULL DROP TABLE dev.dbo.[Orders];
CREATE TABLE dev.dbo.[Orders](
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    BuyerID INT NOT NULL FOREIGN KEY REFERENCES dev.dbo.Buyer(BuyerID),
    SellerID INT NOT NULL FOREIGN KEY REFERENCES dev.dbo.Seller(SellerID),
    UserID INT NULL FOREIGN KEY REFERENCES dev.dbo.[User](UserID),
    ProductID INT NOT NULL FOREIGN KEY REFERENCES dev.dbo.[Product](ProductID),
    InchcapeOrderNo NVARCHAR(50),
    SellerInvoiceNo NVARCHAR(50),
    BuyerPurchaseOrderNo NVARCHAR(50),
    OrderStatus NVARCHAR(50),
    CancelledFlag BIT,
    Quantity INT,
    ProductUnitPrice DECIMAL(18,4),
    ProductTotalPrice DECIMAL(18,4),
    OrderDate DATETIME2
);

INSERT INTO dev.dbo.[Orders]
    (InchcapeOrderNo, BuyerID, SellerID, UserID, ProductID, SellerInvoiceNo, BuyerPurchaseOrderNo, 
     OrderStatus, CancelledFlag, Quantity, ProductUnitPrice, ProductTotalPrice, OrderDate)
SELECT DISTINCT
    s.InchcapeOrderNo,
    b.BuyerID,
    se.SellerID,
    u.UserID,
    p.ProductID,
    s.currency,
    s.SellerInvoiceNo,
    s.BuyerPurchaseOrderNo,
    s.OrderStatus,
    CASE WHEN s.CancelledFlag IS NULL THEN 0 ELSE 1 END as CancelledFlag,
    s.Quantity,
    s.ProductUnitPrice,
    s.ProductTotalPrice,
    s.CreationDate as OrderDate
FROM dev.stg.RawOrder s
JOIN dev.dbo.Buyer b ON s.BuyerAccountNo = b.BuyerAccountNo
JOIN dev.dbo.Seller se ON s.SellerAccountNo = se.SellerAccountNo
JOIN dev.dbo.[User] u ON s.users = u.Username
JOIN dev.dbo.[Product] p ON s.Product = p.ProductCode;