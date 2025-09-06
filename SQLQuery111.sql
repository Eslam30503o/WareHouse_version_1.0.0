create database test;
use test ;
CREATE TABLE Users (
    UserID INT IDENTITY(1,1) PRIMARY KEY,
    Username NVARCHAR(50) NOT NULL UNIQUE,
    Password NVARCHAR(255) NOT NULL,
    Role NVARCHAR(20) NOT NULL CHECK (Role IN ('Admin', 'Manager', 'Worker')),
    CreatedAt DATETIME DEFAULT GETDATE()
);
CREATE TABLE Items (
    ItemID INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL,
    Code NVARCHAR(50) NOT NULL UNIQUE,
    Quantity INT NOT NULL DEFAULT 0,
    MinQuantity INT NOT NULL DEFAULT 0,
    Supplier NVARCHAR(100),
    LastUpdate DATETIME DEFAULT GETDATE()
);
CREATE TABLE Transactions (
    TransactionID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    ItemID INT NOT NULL,
    Action NVARCHAR(50) NOT NULL,
    QuantityChange INT DEFAULT 0,
    Timestamp DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (UserID) REFERENCES Users(UserID),
    FOREIGN KEY (ItemID) REFERENCES Items(ItemID)
);

CREATE PROCEDURE sp_AddItem
    @Name NVARCHAR(100),
    @Code NVARCHAR(50),
    @Quantity INT,
    @MinQuantity INT = 0,
    @Supplier NVARCHAR(100) = NULL
AS
BEGIN
    INSERT INTO Items (Name, Code, Quantity, MinQuantity, Supplier)
    VALUES (@Name, @Code, @Quantity, @MinQuantity, @Supplier);
END;



EXEC sp_AddItem 
    @Code = 'N.810',
    @Name = N'مسمار',
    @Quantity = 100;

CREATE PROCEDURE sp_UpdateQuantity
    @Code NVARCHAR(50),
    @QuantityChange INT,
    @UserID INT,
    @Action NVARCHAR(50)
AS
BEGIN
    DECLARE @ItemID INT;

    -- نجيب ID بتاع الصنف
    SELECT @ItemID = ItemID FROM Items WHERE Code = @Code;

    IF @ItemID IS NOT NULL
    BEGIN
        -- نعدل الكمية
        UPDATE Items
        SET Quantity = Quantity + @QuantityChange,
            LastUpdate = GETDATE()
        WHERE ItemID = @ItemID;

        -- نسجل العملية في Transactions
        INSERT INTO Transactions (UserID, ItemID, Action, QuantityChange)
        VALUES (@UserID, @ItemID, @Action, @QuantityChange);
    END
END;



CREATE PROCEDURE sp_GetLowStockItems
AS
BEGIN
    SELECT ItemID, Name, Code, Quantity, MinQuantity, Supplier
    FROM Items
    WHERE Quantity <= MinQuantity;
END;

DROP PROCEDURE sp_AddItem;

INSERT INTO Users (Username, Password, Role)
VALUES (N'Admin1', N'123456', 'Admin');

-- إضافة صنف جديد
EXEC sp_AddItem 
    @Name = N'مسمار 2',
    @Code = 'N.811',
    @Quantity = 50,
    @MinQuantity = 10,
    @Supplier = N'شركة الحديد';
    -- خصم 10 قطع من المسمار

EXEC sp_UpdateQuantity 
    @Code = 'N.811',
    @QuantityChange = -10,
    @UserID = 1,
    @Action = 'Remove';

-- إضافة 50 قطعة
EXEC sp_UpdateQuantity 
    @Code = 'N.810',
    @QuantityChange = 50,
    @UserID = 1,
    @Action = 'Add';

-- عرض الأصناف الناقصة
EXEC sp_GetLowStockItems;

ALTER TABLE Items
ADD CONSTRAINT CHK_Items_Quantity CHECK (Quantity >= 0);

UPDATE Items
SET Quantity = 0
WHERE Quantity < 0;


CREATE OR ALTER PROCEDURE sp_UpdateQuantity
    @ItemCode NVARCHAR(50),
    @QuantityChange INT,               -- القيمة المضافة أو المخصومة
    @TransactionType NVARCHAR(10),     -- 'IN' أو 'OUT'
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ItemID INT, @CurrentQuantity INT;

    -- جلب بيانات الصنف
    SELECT @ItemID = ItemID, @CurrentQuantity = Quantity
    FROM Items
    WHERE Code = @ItemCode;

    -- لو الصنف مش موجود
    IF @ItemID IS NULL
    BEGIN
        RAISERROR('Item not found.', 16, 1);
        RETURN;
    END;

    -- تحقق من الـ TransactionType
    IF @TransactionType NOT IN ('IN', 'OUT')
    BEGIN
        RAISERROR('Invalid TransactionType. Use IN or OUT.', 16, 1);
        RETURN;
    END;

    -- لو العملية OUT وتؤدي لسالب
    IF @TransactionType = 'OUT' AND @CurrentQuantity - @QuantityChange < 0
    BEGIN
        RAISERROR('Not enough stock. Transaction cancelled.', 16, 1);
        RETURN;
    END;

    -- تحديث الكمية
    UPDATE Items
    SET Quantity = CASE 
                       WHEN @TransactionType = 'IN' THEN Quantity + @QuantityChange
                       WHEN @TransactionType = 'OUT' THEN Quantity - @QuantityChange
                   END,
        LastUpdate = GETDATE()
    WHERE ItemID = @ItemID;

    -- إضافة Transaction
    INSERT INTO Transactions (UserID, ItemID, Action, QuantityChange)
    VALUES (@UserID, @ItemID, @TransactionType, @QuantityChange);
END;


-- إضافة 20 وحدة للصنف
EXEC sp_UpdateQuantity 
    @ItemCode = 'N.811',
    @QuantityChange = 20,
    @TransactionType = 'IN',
    @UserID = 1;

-- محاولة خصم أكتر من الموجود (هتلغي العملية برسالة خطأ)
EXEC sp_UpdateQuantity 
    @ItemCode = 'N.811',
    @QuantityChange = 200,
    @TransactionType = 'OUT',
    @UserID = 1;


CREATE OR ALTER PROCEDURE sp_UpdateQuantity
    @ItemCode NVARCHAR(50),
    @QuantityChange INT,               -- الكمية المطلوبة
    @TransactionType NVARCHAR(10),     -- 'IN' أو 'OUT'
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ItemID INT, @CurrentQuantity INT;

    -- جلب بيانات الصنف
    SELECT @ItemID = ItemID, @CurrentQuantity = Quantity
    FROM Items
    WHERE Code = @ItemCode;

    -- لو الصنف مش موجود
    IF @ItemID IS NULL
    BEGIN
        RAISERROR('Item not found.', 16, 1);
        RETURN;
    END;

    -- تحقق من الـ TransactionType
    IF @TransactionType NOT IN ('IN', 'OUT')
    BEGIN
        RAISERROR('Invalid TransactionType. Use IN or OUT.', 16, 1);
        RETURN;
    END;

    -- تحقق من أن الكمية المطلوبة موجبة
    IF @QuantityChange <= 0
    BEGIN
        RAISERROR('QuantityChange must be greater than zero.', 16, 1);
        RETURN;
    END;

    -- لو العملية OUT وتؤدي لسالب
    IF @TransactionType = 'OUT' AND @CurrentQuantity - @QuantityChange < 0
    BEGIN
        DECLARE @ErrorMessage NVARCHAR(200);
        SET @ErrorMessage = 'Not enough stock. Available: ' 
                            + CAST(@CurrentQuantity AS NVARCHAR(10)) 
                            + ', Requested: ' 
                            + CAST(@QuantityChange AS NVARCHAR(10));
        RAISERROR(@ErrorMessage, 16, 1);
        RETURN;
    END;

    -- تحديث الكمية
    UPDATE Items
    SET Quantity = CASE 
                       WHEN @TransactionType = 'IN' THEN Quantity + @QuantityChange
                       WHEN @TransactionType = 'OUT' THEN Quantity - @QuantityChange
                   END,
        LastUpdate = GETDATE()
    WHERE ItemID = @ItemID;

    -- إضافة Transaction
    INSERT INTO Transactions (UserID, ItemID, Action, QuantityChange)
    VALUES (@UserID, @ItemID, @TransactionType, @QuantityChange);
END;


-- لو عندك الكمية = 10 وحاولت تسحب 20
EXEC sp_UpdateQuantity 
    @ItemCode = 'N.811',
    @QuantityChange = 200,
    @TransactionType = 'OUT',
    @UserID = 1;

CREATE OR ALTER PROCEDURE sp_UpdateQuantity
    @ItemCode NVARCHAR(50),
    @QuantityChange INT,               -- الكمية المطلوبة
    @TransactionType NVARCHAR(10),     -- 'IN' أو 'OUT'
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ItemID INT, @CurrentQuantity INT;

    -- جلب بيانات الصنف
    SELECT @ItemID = ItemID, @CurrentQuantity = Quantity
    FROM Items
    WHERE Code = @ItemCode;

    -- لو الصنف مش موجود
    IF @ItemID IS NULL
    BEGIN
        INSERT INTO Transactions (UserID, ItemID, Action, QuantityChange)
        VALUES (@UserID, NULL, 'FAILED: Item not found', 0);

        SELECT 'Failure' AS Status,
               'Item not found.' AS Message,
               NULL AS AvailableQuantity;
        RETURN;
    END;

    -- تحقق من الـ TransactionType
    IF @TransactionType NOT IN ('IN', 'OUT')
    BEGIN
        INSERT INTO Transactions (UserID, ItemID, Action, QuantityChange)
        VALUES (@UserID, @ItemID, 'FAILED: Invalid TransactionType', 0);

        SELECT 'Failure' AS Status,
               'Invalid TransactionType. Use IN or OUT.' AS Message,
               @CurrentQuantity AS AvailableQuantity;
        RETURN;
    END;

    -- تحقق من أن الكمية المطلوبة موجبة
    IF @QuantityChange <= 0
    BEGIN
        INSERT INTO Transactions (UserID, ItemID, Action, QuantityChange)
        VALUES (@UserID, @ItemID, 'FAILED: Invalid Quantity', @QuantityChange);

        SELECT 'Failure' AS Status,
               'QuantityChange must be greater than zero.' AS Message,
               @CurrentQuantity AS AvailableQuantity;
        RETURN;
    END;

    -- لو العملية OUT وتؤدي لسالب
    IF @TransactionType = 'OUT' AND @CurrentQuantity - @QuantityChange < 0
    BEGIN
        INSERT INTO Transactions (UserID, ItemID, Action, QuantityChange)
        VALUES (@UserID, @ItemID, 'FAILED: Not enough stock', @QuantityChange);

        SELECT 'Failure' AS Status,
               'Not enough stock. Available: ' 
               + CAST(@CurrentQuantity AS NVARCHAR(10)) 
               + ', Requested: ' 
               + CAST(@QuantityChange AS NVARCHAR(10)) AS Message,
               @CurrentQuantity AS AvailableQuantity;
        RETURN;
    END;

    -- تحديث الكمية
    UPDATE Items
    SET Quantity = CASE 
                       WHEN @TransactionType = 'IN' THEN Quantity + @QuantityChange
                       WHEN @TransactionType = 'OUT' THEN Quantity - @QuantityChange
                   END,
        LastUpdate = GETDATE()
    WHERE ItemID = @ItemID;

    -- إضافة Transaction ناجحة
    INSERT INTO Transactions (UserID, ItemID, Action, QuantityChange)
    VALUES (@UserID, @ItemID, @TransactionType, @QuantityChange);

    -- رجع النتيجة النهائية
    SELECT 'Success' AS Status,
           'Transaction completed successfully.' AS Message,
           (SELECT Quantity FROM Items WHERE ItemID = @ItemID) AS AvailableQuantity;
END;


CREATE VIEW vw_CurrentStock AS
SELECT 
    ItemID,
    Code,
    Name,
    Quantity,
    MinQuantity,
    CASE 
        WHEN Quantity <= MinQuantity THEN '⚠️ Reorder Needed'
        ELSE 'OK'
    END AS Status,
    LastUpdate
FROM Items;


CREATE VIEW vw_ItemTransactions AS
SELECT 
    T.TransactionID,
    I.Code AS ItemCode,
    I.Name AS ItemName,
    U.Username,
    T.Action,
    T.QuantityChange,
    T.Timestamp
FROM Transactions T
JOIN Items I ON T.ItemID = I.ItemID
JOIN Users U ON T.UserID = U.UserID;

CREATE VIEW vw_TopMovingItems AS
SELECT 
    I.Code,
    I.Name,
    SUM(ABS(T.QuantityChange)) AS TotalMovement
FROM Transactions T
JOIN Items I ON T.ItemID = I.ItemID
GROUP BY I.Code, I.Name
ORDER BY TotalMovement DESC;

CREATE VIEW vw_TopMovingItems AS
SELECT 
    I.Code,
    I.Name,
    SUM(ABS(T.QuantityChange)) AS TotalMovement
FROM Transactions T
JOIN Items I ON T.ItemID = I.ItemID
GROUP BY I.Code, I.Name;

SELECT * FROM vw_TopMovingItems
ORDER BY TotalMovement DESC;



SELECT * FROM vw_CurrentStock;
SELECT * FROM vw_ItemTransactions;
SELECT * FROM vw_TopMovingItems;
SELECT * FROM vw_UserActivity;
SELECT * FROM vw_ReorderItems;


CREATE VIEW vw_UserActivity AS
SELECT 
    U.UserID,
    U.Username,
    U.Role,
    COUNT(T.TransactionID) AS TotalTransactions,
    SUM(T.QuantityChange) AS NetQuantityChange,  -- موجب = دخل مخزن, سالب = خرج من المخزن
    MAX(T.Timestamp) AS LastAction
FROM Users U
LEFT JOIN Transactions T ON U.UserID = T.UserID
GROUP BY U.UserID, U.Username, U.Role;


CREATE VIEW vw_ReorderItems AS
SELECT 
    ItemID,
    Code,
    Name,
    Quantity,
    MinQuantity,
    Supplier,
    LastUpdate
FROM Items
WHERE Quantity <= MinQuantity;


SELECT * FROM Items;

SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Items';
