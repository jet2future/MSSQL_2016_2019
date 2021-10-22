/* script name: ServerInfo.sql 
   gathers sql server version and edition 
*/ 
  
SET NOCOUNT ON 
  
DECLARE @SqlVersion varchar(200) 
SET @SqlVersion=@@VERSION 
  
SELECT @@SERVERNAME as 'Server Name', 
       @SqlVersion as 'Version', 
       SERVERPROPERTY('edition') as 'Edition', 
       SERVERPROPERTY('productlevel') as 'Service Pack' 
PRINT '' 
GO 
