USE $(DBName)
GO
print '$(DBName)'

exec usp_delete_job '$(DBName)'

print '$(ServerName)'

exec usp_create_job '$(ServerName)', '$(DBName)', '$(UserName)', '$(Pswd)',  '$(WindowsAuth)'
GO