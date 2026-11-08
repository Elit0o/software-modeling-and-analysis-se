create database F1TV
go

use F1TV
go

create table Users(
	UserId int identity(1,1) primary key,
	Email varchar(50) unique not null,
	Password varchar(150) not null,
	FirstName varchar(50) not null,
	LastName varchar(50) not null,
	CountryCode char(2) not null,
	CreatedAt datetime default getdate()
)

create table SubscriptionPlans(
	PlanId int identity(1,1) primary key,
	PlanName varchar(50) not null,
	MonthlyFee decimal(5,2) not null,
	IsLiveAllowed bit not null
)

create table Subscriptions(
	SubscriptionId int identity(1,1) primary key,
	UserId int not null,
	PlanId int not null,
	StartDate datetime default getdate(),
	EndDate datetime not null,
	IsActive bit default 1,
	constraint FK_Subscriptions_Users foreign key (UserId) references Users(UserId),
	constraint FK_Subscriptions_Plans foreign key (PlanId) references SubscriptionPlans(PlanId)
)

create table Teams(
	TeamId int identity(1,1) primary key,
	TeamName varchar(100) not null,
	BaseCountry varchar(50) not null,
	TeamPrincipal varchar(100) not null
)

create table Drivers(
	DriverId int identity(1,1) primary key,
	TeamId int not null,
	FirstName varchar(50) not null,
	LastName varchar(50) not null,
	DriverNumber int not null,
	Country varchar(50) not null,
	constraint FK_Driver_Teams foreign key (TeamId) references Teams(TeamId)
)

create table Races(
	RaceId int identity(1,1) primary key,
	GrandPrixName varchar(100) not null,
	CircuitName varchar(100) not null,
	Country varchar(50) not null, -- КОРИГИРАНО: Беше datetime, а трябва да е стрингово поле за държавата
	RaceDate datetime not null,
	TotalLaps int not null
)

create table RaceResult(
	ResultId int identity(1,1) primary key,
	DriverId int not null,
	RaceId int not null,
	GridPosition int not null,
	FinishPosition int null,
	constraint FK_RaceResult_Drivers foreign key (DriverId) references Drivers(DriverId),
	constraint FK_RaceResult_Races foreign key (RaceId) references Races(RaceId)
)

create table VideoStreams(
	StreamId int identity(1,1) primary key,
	RaceId int not null,
	DriverId int null, -- КОРИГИРАНО: Позволява NULL, тъй като главният стрийм (Main Feed) няма конкретен пилот
	StreamType varchar(50) not null,
	QualityMax varchar(20) not null,
	constraint FK_VideoStreams_Races foreign key (RaceId) references Races(RaceId),
	constraint FK_VideoStreams_Drivers foreign key (DriverId) references Drivers(DriverId)
)

create table UserWatchHistory (
	WatchId int identity(1,1) primary key,
	UserId int not null,
	StreamId int not null,
	WatchDurationInMinutes int not null,
	LastWatchedTime datetime default getdate(),
	constraint FK_WatchHistory_Users foreign key (UserId) references Users(UserId),
	constraint FK_WatchHitory_Streams foreign key (StreamId) references VideoStreams(StreamId)
)

-- Data (с ISO формат на датите за сигурност)

insert into SubscriptionPlans (PlanName, MonthlyFee, IsLiveAllowed) values
('F1 Access', 2.99, 0),
('F1 TV Pro', 7.99, 1);

insert into Users (Email, Password, FirstName, LastName, CountryCode) values
('ivan.ivanov@gmail.com', 'hash_pass_1', 'Иван', 'Иванов', 'BG'),
('petar.petrov@abv.bg', 'hash_pass_2', 'Петър', 'Петров', 'BG');

insert into Subscriptions (UserId, PlanId, StartDate, EndDate, IsActive) values
(1, 2, '2026-03-01T00:00:00', '2026-11-30T00:00:00', 1),
(2, 1, '2026-05-01T00:00:00', '2026-06-01T00:00:00', 0);

insert into Teams (TeamName, BaseCountry, TeamPrincipal) values
('Red Bull Racing', 'Austria', 'Christian Horner'),
('Ferrari', 'Italy', 'Frederic Vasseur');

insert into Drivers (TeamId, FirstName, LastName, DriverNumber, Country) values
(1, 'Max', 'Verstappen', 1, 'Netherlands'),
(2, 'Charles', 'Leclerc', 16, 'Monaco');

insert into Races (GrandPrixName, CircuitName, Country, RaceDate, TotalLaps) values
('Italian Grand Prix', 'Monza', 'Italy', '2026-09-06T16:00:00', 53),
('Monaco Grand Prix', 'Circuit de Monaco', 'Monaco', '2026-05-24T16:00:00', 78);

insert into RaceResult (DriverId, RaceId, GridPosition, FinishPosition) values
(1, 1, 1, 1),
(2, 1, 2, 2);

insert into VideoStreams (RaceId, DriverId, StreamType, QualityMax) values
(1, NULL, 'Main Feed', '1080p'),
(1, 1, 'Onboard Camera', '1080p');

insert into UserWatchHistory (UserId, StreamId, WatchDurationInMinutes) values
(1, 1, 120),
(1, 2, 90);


-- Stored Procedure
create procedure sp_RegisterUser
	@Email VARCHAR(50),
    @Password VARCHAR(150),
    @FirstName VARCHAR(50),
    @LastName VARCHAR(50),
    @CountryCode CHAR(2)
as
begin
	insert into Users(Email, Password, FirstName, LastName, CountryCode)
	values (@Email, @Password, @FirstName, @LastName, @CountryCode);
end


-- Function
create function fn_GetTotalWatchTimeByUser(@UserId int)
returns int
as
begin
	declare @TotalMinutes int
	select @TotalMinutes = isnull(sum(WatchDurationInMinutes), 0) from UserWatchHistory
	where UserId = @UserId;

	return @TotalMinutes
end


-- Trigger
create trigger trg_CheckSubscriptionExpiration
on Subscriptions
after insert, update
as
begin
	update Subscriptions
	set IsActive = 0
	from Subscriptions sub
	inner join inserted i on sub.SubscriptionId = i.SubscriptionId
	where sub.EndDate < getdate()
end

EXEC sp_RegisterUser 'georgi.georgiev@gmail.com', 'pass123', 'Георги', 'Георгиев', 'BG';
SELECT * FROM Users;

SELECT dbo.fn_GetTotalWatchTimeByUser(1) AS TotalWatchMinutes;

INSERT INTO Subscriptions (UserId, PlanId, StartDate, EndDate, IsActive) 
VALUES (1, 1, '2023-01-01', '2023-02-01', 1);

SELECT * FROM Subscriptions WHERE UserId = 1;