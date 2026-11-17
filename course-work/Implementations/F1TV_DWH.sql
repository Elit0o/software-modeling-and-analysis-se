CREATE DATABASE F1TV_DWH;
GO

USE F1TV_DWH;
GO


CREATE TABLE Dim_Date (
    DateKey INT PRIMARY KEY,
    FullDate DATE NOT NULL,
    Year INT NOT NULL,
    Quarter INT NOT NULL,
    Month INT NOT NULL,
    MonthName VARCHAR(20) NOT NULL
);

CREATE TABLE Dim_User (
    UserKey INT IDENTITY(1,1) PRIMARY KEY,
    UserId INT NOT NULL,
    FullName VARCHAR(105) NOT NULL,
    CountryCode CHAR(2) NOT NULL
);

CREATE TABLE Dim_Plan (
    PlanKey INT IDENTITY(1,1) PRIMARY KEY,
    PlanId INT NOT NULL,
    PlanName VARCHAR(50) NOT NULL,
    MonthlyFee DECIMAL(5,2) NOT NULL,
    IsLiveAllowed BIT NOT NULL
);

CREATE TABLE Dim_Race (
    RaceKey INT IDENTITY(1,1) PRIMARY KEY,
    RaceId INT NOT NULL,
    GrandPrixName VARCHAR(100) NOT NULL,
    CircuitName VARCHAR(100) NOT NULL,
    Country VARCHAR(50) NOT NULL
);

CREATE TABLE Dim_Driver (
    DriverKey INT IDENTITY(1,1) PRIMARY KEY,
    DriverId INT NOT NULL,
    DriverName VARCHAR(105) NOT NULL,
    DriverNumber INT NOT NULL,
    TeamName VARCHAR(100) NOT NULL
);

CREATE TABLE Dim_StreamType (
    StreamTypeKey INT IDENTITY(1,1) PRIMARY KEY,
    StreamType VARCHAR(50) NOT NULL,
    QualityMax VARCHAR(20) NOT NULL
);
GO

CREATE TABLE Fact_UserStreams (
    FactStreamId INT IDENTITY(1,1) PRIMARY KEY,
    DateKey INT FOREIGN KEY REFERENCES Dim_Date(DateKey),
    UserKey INT FOREIGN KEY REFERENCES Dim_User(UserKey),
    RaceKey INT FOREIGN KEY REFERENCES Dim_Race(RaceKey),
    DriverKey INT NULL FOREIGN KEY REFERENCES Dim_Driver(DriverKey),
    StreamTypeKey INT FOREIGN KEY REFERENCES Dim_StreamType(StreamTypeKey),
    WatchDurationMinutes INT NOT NULL,
    SessionCount INT DEFAULT 1
);

CREATE TABLE Fact_SubscriptionRevenue (
    FactRevenueId INT IDENTITY(1,1) PRIMARY KEY,
    DateKey INT FOREIGN KEY REFERENCES Dim_Date(DateKey),
    UserKey INT FOREIGN KEY REFERENCES Dim_User(UserKey),
    PlanKey INT FOREIGN KEY REFERENCES Dim_Plan(PlanKey),
    RevenueAmount DECIMAL(5,2) NOT NULL,
    IsActive INT NOT NULL
);

CREATE TABLE Fact_RacePerformance (
    FactPerformanceId INT IDENTITY(1,1) PRIMARY KEY,
    DateKey INT FOREIGN KEY REFERENCES Dim_Date(DateKey),
    RaceKey INT FOREIGN KEY REFERENCES Dim_Race(RaceKey),
    DriverKey INT FOREIGN KEY REFERENCES Dim_Driver(DriverKey),
    GridPosition INT NOT NULL,
    FinishPosition INT NOT NULL,
    PositionsGained INT NOT NULL
);
GO

INSERT INTO Dim_User (UserId, FullName, CountryCode)
SELECT UserId, FirstName + ' ' + LastName, CountryCode FROM F1TV.dbo.Users;

INSERT INTO Dim_Plan (PlanId, PlanName, MonthlyFee, IsLiveAllowed)
SELECT PlanId, PlanName, MonthlyFee, IsLiveAllowed FROM F1TV.dbo.SubscriptionPlans;

INSERT INTO Dim_Race (RaceId, GrandPrixName, CircuitName, Country)
SELECT RaceId, GrandPrixName, CircuitName, Country FROM F1TV.dbo.Races;

INSERT INTO Dim_Driver (DriverId, DriverName, DriverNumber, TeamName)
SELECT d.DriverId, d.FirstName + ' ' + d.LastName, d.DriverNumber, t.TeamName
FROM F1TV.dbo.Drivers d
JOIN F1TV.dbo.Teams t ON d.TeamId = t.TeamId;

INSERT INTO Dim_StreamType (StreamType, QualityMax)
SELECT DISTINCT StreamType, QualityMax FROM F1TV.dbo.VideoStreams;

INSERT INTO Dim_Date (DateKey, FullDate, Year, Quarter, Month, MonthName)
SELECT DISTINCT 
    CAST(CONVERT(VARCHAR(8), d.dt, 112) AS INT),
    CAST(d.dt AS DATE),
    YEAR(d.dt),
    DATEPART(QUARTER, d.dt),
    MONTH(d.dt),
    DATENAME(MONTH, d.dt)
FROM (
    SELECT StartDate AS dt FROM F1TV.dbo.Subscriptions
    UNION
    SELECT RaceDate FROM F1TV.dbo.Races
    UNION
    SELECT LastWatchedTime FROM F1TV.dbo.UserWatchHistory
) AS d;
GO

INSERT INTO Fact_UserStreams (DateKey, UserKey, RaceKey, DriverKey, StreamTypeKey, WatchDurationMinutes, SessionCount)
SELECT 
    CAST(CONVERT(VARCHAR(8), wh.LastWatchedTime, 112) AS INT),
    du.UserKey,
    dr.RaceKey,
    dd.DriverKey,
    dst.StreamTypeKey,
    wh.WatchDurationInMinutes,
    1
FROM F1TV.dbo.UserWatchHistory wh
JOIN Dim_User du ON wh.UserId = du.UserId
JOIN F1TV.dbo.VideoStreams vs ON wh.StreamId = vs.StreamId
JOIN Dim_Race dr ON vs.RaceId = dr.RaceId
LEFT JOIN Dim_Driver dd ON vs.DriverId = dd.DriverId
JOIN Dim_StreamType dst ON vs.StreamType = dst.StreamType AND vs.QualityMax = dst.QualityMax;
GO

INSERT INTO Fact_SubscriptionRevenue (DateKey, UserKey, PlanKey, RevenueAmount, IsActive)
SELECT 
    CAST(CONVERT(VARCHAR(8), s.StartDate, 112) AS INT),
    du.UserKey,
    dp.PlanKey,
    dp.MonthlyFee,
    CAST(s.IsActive AS INT)
FROM F1TV.dbo.Subscriptions s
JOIN Dim_User du ON s.UserId = du.UserId
JOIN Dim_Plan dp ON s.PlanId = dp.PlanId;
GO

INSERT INTO Fact_RacePerformance (DateKey, RaceKey, DriverKey, GridPosition, FinishPosition, PositionsGained)
SELECT 
    CAST(CONVERT(VARCHAR(8), r.RaceDate, 112) AS INT),
    dr.RaceKey,
    dd.DriverKey,
    rr.GridPosition,
    rr.FinishPosition,
    (rr.GridPosition - rr.FinishPosition)
FROM F1TV.dbo.RaceResult rr
JOIN F1TV.dbo.Races r ON rr.RaceId = r.RaceId
JOIN Dim_Race dr ON r.RaceId = dr.RaceId
JOIN Dim_Driver dd ON rr.DriverId = dd.DriverId;
GO