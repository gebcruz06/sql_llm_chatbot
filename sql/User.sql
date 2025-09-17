IF OBJECT_ID('dev.dbo.User', 'U') IS NOT NULL DROP TABLE dev.dbo.[User];
CREATE TABLE dev.dbo.[User] (
    UserID INT IDENTITY(1,1) PRIMARY KEY,
    Username NVARCHAR(255) NOT NULL UNIQUE,
    FullName NVARCHAR(255),
    LastLogin DATETIME2,
    LastUpdate DATETIME2,
    UpdatedBy NVARCHAR(255)
);

INSERT INTO dev.dbo.[User] (Username, FullName, LastLogin, LastUpdate, UpdatedBy)
SELECT DISTINCT
    users AS Username,
    username AS FullName,
    lastLogin,
    LastUpdate,
    UpdatedBy
FROM dev.stg.RawOrder
WHERE users IS NOT NULL;