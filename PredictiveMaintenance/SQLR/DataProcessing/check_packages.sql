set nocount on;
go

drop table if exists #results;
go

create table #results
(
	[packages] nvarchar(100) not null,
	[installed] bit not null
);
go

drop procedure if exists #stpCheckInstalledPackages;
go

create procedure #stpCheckInstalledPackages
as
exec sp_execute_external_script @language=N'R',    
@script=N'
packages = c("plyr", "zoo")
packagesInstalled = packages %in% rownames(installed.packages())
OutputDataSet = data.frame(packages, packagesInstalled)
'
with result sets (as object #results)
go    

insert into #results exec #stpCheckInstalledPackages
go

if (exists(select * from #results where installed = 0))
	throw 50000, 'Needed packages are not installed', 1;
go