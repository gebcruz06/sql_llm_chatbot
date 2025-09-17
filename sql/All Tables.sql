/* =============================
   USERS
   ============================= */
IF OBJECT_ID('dev.dbo.Users', 'U') IS NOT NULL DROP TABLE dev.dbo.Users;
CREATE TABLE dev.dbo.Users (
    UserID INT IDENTITY(1,1) PRIMARY KEY,
    Username NVARCHAR(255) NOT NULL UNIQUE,
    FullName NVARCHAR(255),
    LastLogin DATETIME2,
    LastUpdate DATETIME2,
    UpdatedBy NVARCHAR(255)
);

/* =============================
   BUYERS
   ============================= */
IF OBJECT_ID('dev.dbo.Buyers', 'U') IS NOT NULL DROP TABLE dev.dbo.Buyers;
CREATE TABLE dev.dbo.Buyers (
    BuyerID INT IDENTITY(1,1) PRIMARY KEY,
    BuyerAccountNo NVARCHAR(50) NOT NULL UNIQUE,
    BuyerTradingName NVARCHAR(255)
);

/* =============================
   SELLERS
   ============================= */
IF OBJECT_ID('dev.dbo.Sellers', 'U') IS NOT NULL DROP TABLE dev.dbo.Sellers;
CREATE TABLE dev.dbo.Sellers (
    SellerID INT IDENTITY(1,1) PRIMARY KEY,
    SellerAccountNo NVARCHAR(50) NOT NULL UNIQUE,
    SellerTradingName NVARCHAR(255),
    Site NVARCHAR(100)
);

/* =============================
   CATEGORIES
   ============================= */
IF OBJECT_ID('dev.dbo.Categories', 'U') IS NOT NULL DROP TABLE dev.dbo.Categories;
CREATE TABLE dev.dbo.Categories (
    CategoryID INT IDENTITY(1,1) PRIMARY KEY,
    Level1Category NVARCHAR(255) NOT NULL UNIQUE
);

/* =============================
   PRODUCTS
   ============================= */
IF OBJECT_ID('dev.dbo.Products', 'U') IS NOT NULL DROP TABLE dev.dbo.Products;
CREATE TABLE dev.dbo.Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductCode NVARCHAR(50) NOT NULL UNIQUE,
    ProductName NVARCHAR(255),
    CategoryID INT NULL FOREIGN KEY REFERENCES dev.dbo.Categories(CategoryID)
);

/* =============================
   ORDERS
   ============================= */
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

/* =============================
   ORDER LINES
   ============================= */
IF OBJECT_ID('dev.dbo.OrderLines', 'U') IS NOT NULL DROP TABLE dev.dbo.OrderLines;
CREATE TABLE dev.dbo.OrderLines (
    OrderLineID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NOT NULL FOREIGN KEY REFERENCES dev.dbo.Orders(OrderID),
    ProductID INT NOT NULL FOREIGN KEY REFERENCES dev.dbo.Products(ProductID),
    Quantity INT,
    ProductUnitPrice DECIMAL(18,4),
    ProductTotalPrice DECIMAL(18,4)
);
