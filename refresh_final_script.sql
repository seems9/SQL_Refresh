=====================================================================
Step 0 - MOVE APPROPRIATE FILES
=====================================================================

  *******************
  **REFRESH PROCESS**
  *******************
--CONNECT TO TARGET SERVER
--OPEN UP TWO EXPLORER WINDOWS (SOURCE LEFT, PATH RIGHT)

--COPY BACKUP FROM PRODUCTION TO REFRESH TARGET
--CHECK CORRECT DRIVE LOCATION

--RENAME BACKUP FILE ON TARGET
[DatabaseName]_refresh.bak

=====================================================================
STEP 1 - Store user info in table
=====================================================================
USE [DatabaseName]
GO
SET NOCOUNT ON
-- Create variable table
DECLARE @db varchar (20)
DECLARE @userbase TABLE
(tusername varchar(30),
 tgroupname varchar(30),
 tloginname varchar(30),
 tdefdbname varchar(30),
 tdefschemaname varchar(30),
 tuserid varchar(5),
 tsid varchar(150))

DECLARE @DBbase TABLE
(tusername varchar(30),
 tgroupname varchar(30),
 tloginname varchar(30),
 tdefdbname varchar(30),
 tdefschemaname varchar(30),
 tuserid varchar(5),
 tsid varchar(150))

-- Insert users into variable table using sp_helpuser
INSERT INTO @userbase
   EXEC sp_helpuser

-- Create Database Users

select distinct 'create user [' + tusername + ']' + case tloginname when isnull(tloginname,'') then + ' FOR LOGIN [' + tusername + ']'
else + '  ' end + case tdefschemaname when isnull (tdefschemaname,'') then + 'WITH DEFAULT_SCHEMA=[' + tdefschemaname + ']'
else + ' ' end as "DBUsers", tusername as username
into [dbo].##usertbl
FROM @userbase
WHERE tusername NOT IN ('dbo', 'INFORMATION_SCHEMA', 'sys', 'guest')

ALTER TABLE [dbo].##usertbl ADD id INT IDENTITY(1,1)

-- Assign Permissions
SELECT 'EXEC sp_addrolemember '''+ tgroupname + ''', ''' + tusername + ''''  as "DBPermissions" 
into [dbo].##permtbl
FROM @userbase
WHERE tusername NOT IN ('dbo', 'INFORMATION_SCHEMA', 'sys', 'guest')
AND tgroupname NOT IN ('public')
ORDER BY tusername
SET NOCOUNT OFF 

ALTER TABLE [dbo].##permtbl ADD id2 INT IDENTITY(1,1)

select * from [dbo].##usertbl
select * from [dbo].##permtbl

=====================================================================
STEP 2 - Restore the Table
=====================================================================
--restore database
use master
GO
ALTER DATABASE [DatabaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
RESTORE DATABASE [DatabaseName] 
FROM  DISK = N'U:\MSSQL10.SQL01\MSSQL\Backup\[DatabaseName]\[DatabaseName]_refresh.bak' 
WITH  FILE = 1,  NOUNLOAD,  REPLACE,  STATS = 10
GO
ALTER DATABASE [DatabaseName] SET MULTI_USER
GO

=====================================================================
STEP 3 - Drop all table info
=====================================================================
use [DatabaseName]
DECLARE @userbase TABLE
(tusername varchar(30),
 tgroupname varchar(30),
 tloginname varchar(30),
 tdefdbname varchar(30),
 tdefschemaname varchar(30),
 tuserid varchar(5),
 tsid varchar(150))

INSERT INTO @userbase
   EXEC sp_helpuser

-- Create Database Users

select distinct tusername as username
into [dbo].##allusers
FROM @userbase
WHERE tusername NOT IN ('dbo', 'INFORMATION_SCHEMA', 'sys', 'guest')
ALTER TABLE [dbo].##allusers ADD uid INT IDENTITY(1,1)

select * from [dbo].##allusers

DECLARE @counter int = 1

WHILE (@counter <= (SELECT COUNT(*) FROM [dbo].##allusers))
BEGIN
	DECLARE @sSQL nvarchar(max)
	SET @sSQL = ''
	Set @sSQL= (SELECT  username FROM [dbo].##allusers where uid=@counter)

	Set @sSQL = 'DROP user'+' '+ '['+ @sSQL +']'
	Execute sp_ExecuteSQL @sSQL
	SET @counter = @counter + 1
END
Drop Table [dbo].##allusers

=====================================================================
STEP 4 - Restore dev users and permissions and then drop tables
=====================================================================
use [DatabaseName]

SELECT * FROM [dbo].##usertbl
DECLARE @counter int = 1

WHILE (@counter <= (SELECT COUNT(*) FROM [dbo].##usertbl))
BEGIN
	DECLARE @query NVARCHAR(MAX);
	
	SET @query = (SELECT DBUsers FROM [dbo].##usertbl where id=@counter)
		

	Execute sp_ExecuteSQL @query
	SET @counter = @counter + 1
END

SELECT * FROM [dbo].##permtbl
DECLARE @counter2 int = 1

WHILE (@counter2 <= (SELECT COUNT(*) FROM [dbo].##permtbl))
BEGIN
	DECLARE @query2 NVARCHAR(MAX);
	
	SET @query2 = (SELECT DBPermissions FROM [dbo].##permtbl where id2=@counter2)
		

	Execute sp_ExecuteSQL @query2
	SET @counter2 = @counter2 + 1
END

drop table [dbo].##usertbl
drop table [dbo].##permtbl
