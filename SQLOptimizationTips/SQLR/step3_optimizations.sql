USE master
GO

-- Step 1: Setup Soft-NUMA
alter server configuration
set process affinity numanode = 0 to 1


-- Step 2: Create SQL query to determine the CPUs to be allocated per resource pool 
declare @bucket_count int = 4;
with t as (
	select ntile(@bucket_count) over (order by cpu_id) as bucket, cpu_id, scheduler_id
         from sys.dm_os_schedulers
        where status like 'VISIBLE%' and parent_node_id <> 64
), t1 as (
	select bucket-1 as bucket, min(cpu_id) as min_cpu, max(cpu_id) as max_cpu
            , SUBSTRING((select CONCAT(',', scheduler_id)
                           from t c2
                          where c2.bucket = t.bucket
                            for xml path('')), 2, 8000) as scheduler_range
         from t
        group by bucket
)
select bucket, scheduler_range, min_cpu, max_cpu
from t1;


-- Step 3: Create resource pools for workload groups

-- This memory configuration gives us the best performance
ALTER RESOURCE POOL "default" WITH (max_memory_percent = 30);
ALTER EXTERNAL RESOURCE POOL "default" WITH (max_memory_percent = 70); 
ALTER RESOURCE GOVERNOR reconfigure; 

IF EXISTS (
    SELECT name
    FROM sys.resource_governor_resource_pools
    WHERE name = N'rpl1')
DROP RESOURCE POOL rpl1;
GO

CREATE RESOURCE POOL rpl1
WITH ( 
	AFFINITY SCHEDULER = (0 TO 4)
)
GO

IF EXISTS (
    SELECT name
    FROM sys.resource_governor_resource_pools
    WHERE name = N'rpl2')
DROP RESOURCE POOL rpl2;
GO

CREATE RESOURCE POOL rpl2
WITH ( 
	AFFINITY SCHEDULER = (5 TO 9)
)
GO

IF EXISTS (
    SELECT name
    FROM sys.resource_governor_resource_pools
    WHERE name = N'rpl3')
DROP RESOURCE POOL rpl3;
GO

CREATE RESOURCE POOL rpl3
WITH ( 
	AFFINITY SCHEDULER = (10 TO 14)
)
GO

IF EXISTS (
    SELECT name
    FROM sys.resource_governor_resource_pools
    WHERE name = N'rpl4')
DROP RESOURCE POOL rpl4;
GO

CREATE RESOURCE POOL rpl4
WITH ( 
	AFFINITY SCHEDULER = (15 TO 19)
)
GO

IF EXISTS (
    SELECT name
    FROM sys.resource_governor_external_resource_pools
    WHERE name = N'rpl1')
DROP EXTERNAL RESOURCE POOL rpl1;
GO

CREATE EXTERNAL RESOURCE POOL rpl1
WITH ( 
	AFFINITY CPU = (0 TO 4)
)
GO

IF EXISTS (
    SELECT name
    FROM sys.resource_governor_external_resource_pools
    WHERE name = N'rpl2')
DROP EXTERNAL RESOURCE POOL rpl2;
GO

CREATE EXTERNAL RESOURCE POOL rpl2
WITH ( 
	AFFINITY CPU = (5 TO 9)
)
GO

IF EXISTS (
    SELECT name
    FROM sys.resource_governor_external_resource_pools
    WHERE name = N'rpl3')
DROP EXTERNAL RESOURCE POOL rpl3;
GO

CREATE EXTERNAL RESOURCE POOL rpl3
WITH ( 
	AFFINITY CPU = (10 TO 14)
)
GO

IF EXISTS (
    SELECT name
    FROM sys.resource_governor_external_resource_pools
    WHERE name = N'rpl4')
DROP EXTERNAL RESOURCE POOL rpl4;
GO

CREATE EXTERNAL RESOURCE POOL rpl4
WITH ( 
	AFFINITY CPU = (15 TO 19)
)
GO

ALTER RESOURCE GOVERNOR reconfigure; 

SELECT * FROM sys.resource_governor_workload_groups; 
SELECT * FROM sys.resource_governor_resource_pools;
SELECT * FROM sys.resource_governor_external_resource_pools; 
SELECT * FROM sys.resource_governor_external_resource_pool_affinity;


-- Step 4: Create and assign workload group to resource pools
IF EXISTS(
    SELECT name
    FROM sys.resource_governor_workload_groups
    WHERE name = N'wg0')
DROP WORKLOAD GROUP wg0;
GO

CREATE WORKLOAD GROUP wg0
USING "rpl1", EXTERNAL "rpl1";
GO

IF EXISTS(
    SELECT name
    FROM sys.resource_governor_workload_groups
    WHERE name = N'wg1')
DROP WORKLOAD GROUP wg1;
GO

CREATE WORKLOAD GROUP wg1
USING "rpl2", EXTERNAL "rpl2";
GO

IF EXISTS(
    SELECT name
    FROM sys.resource_governor_workload_groups
    WHERE name = N'wg2')
DROP WORKLOAD GROUP wg2;
GO

CREATE WORKLOAD GROUP wg2
USING "rpl3", EXTERNAL "rpl3";
GO

IF EXISTS(
    SELECT name
    FROM sys.resource_governor_workload_groups
    WHERE name = N'wg3')
DROP WORKLOAD GROUP wg3;
GO

CREATE WORKLOAD GROUP wg3
USING "rpl4", EXTERNAL "rpl4";
GO

ALTER RESOURCE GOVERNOR reconfigure;

-- Step 5: Create UDF to route workload group 
drop function if exists assign_workload_group;
go
create function assign_workload_group()
returns sysname
with schemabinding
as
begin
       return case when APP_NAME() like '% - PredictionJob'
               then concat('wg', cast(left(APP_NAME()
                             , charindex('-', APP_NAME())-1) as int) % 4)
               else 'default'
              end;
end;
go


-- Step 6: Enable Resource Governer with UDF classifier 
ALTER RESOURCE GOVERNOR
WITH (CLASSIFIER_FUNCTION=dbo.assign_workload_group);
GO
ALTER RESOURCE GOVERNOR RECONFIGURE
GO