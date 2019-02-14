USE $(DBName)
GO
print '$(DBName)'

print 'Deleting job'
exec usp_delete_job '$(DBName)'
GO
print 'Deleted job'
print '$(ServerName)'
print '$(Port)'
declare @server varchar(100)

if (rtrim(ltrim('$(Port)')) <> 'NA')
	set @server = concat('$(ServerName)',",", '$(Port)')
else
	set @server = '$(ServerName)'

exec usp_create_job @server, '$(DBName)', '$(UserName)', '$(Pswd)',  '$(WindowsAuth)'
GO


