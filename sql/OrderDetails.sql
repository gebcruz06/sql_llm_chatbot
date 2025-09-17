IF OBJECT_ID('dev.dbo.OrderDetails', 'U') IS NOT NULL DROP TABLE dev.dbo.OrderDetails;
CREATE TABLE dev.dbo.OrderDetails (
    OrderLineID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NOT NULL FOREIGN KEY REFERENCES dev.dbo.Orders(OrderID),
    ProductID INT NOT NULL FOREIGN KEY REFERENCES dev.dbo.Products(ProductID),
    Quantity INT,
    ProductUnitPrice DECIMAL(18,4),
    ProductTotalPrice DECIMAL(18,4)
);

INSERT INTO dev.dbo.OrderDetails (OrderID, ProductID, Quantity, ProductUnitPrice, ProductTotalPrice)
SELECT
    o.OrderID,
    p.ProductID,
    s.quantity,
    s.ProductUnitPrice,
    s.ProductTotalPrice
FROM dev.dbo.StagingOrders s
JOIN dev.dbo.Orders o ON s.InchcapeOrderNo = o.InchcapeOrderNo
JOIN dev.dbo.Products p ON s.Product = p.ProductCode;