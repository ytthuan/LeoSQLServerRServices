# SQL Optimization Tips and Tricks for Analytics Services

## Introduction

In SQL Server 2016, a new function, which is called R services, has been added. SQL Server 2016 R Services provides a platform for operationalize R scripts using T-SQL to develop and deploy intelligent applications. This Markdown file will describe the design and key optimization techniques for a resume-matching scenario that demonstrates how we can find the best candidates for a job opening among millions of resumes within a few seconds.

## Use Case

Finding the best candidate for a job opening has long been an art that is labor intensive and requires manual efforts from search agents. With the advent of social media and big data, recruiting has entered a new era where methods are changing and strategies are evolving. How to find candidates with certain technical or specialized qualities from massive information that collected from devising sources has become a new big challenge.

We developed a model to search good matches among millions of resumes for a giving position. This model will take both the resume and job description as inputs and we formulate it as a binary classification problem. The model will output the probability of being a good match for each resume-job pair. A user defined probability threshold is then used to further filter good matches.

A key challenge in this use case is how to convert unstructured text feature into numerical features. We used topic modeling technique to achieve the goal. In this tutorial, we ignored to show the step of training the resume and position topic models since we cannot find an equivalent public dataset or generate such a dataset.

## Hardware Specifications

The hardware used in this tutorial is '**SQL Server 2016 SP1 Enterprise on Windows Server 2016**' on Azure. This edition has been pre-configured with Microsoft R Server (in-database) installation. Microsoft R Server provides the option to develop high performance R solutions on Windows while connecting to the database or data source of your choice. The detailed hardware configuration is show as follows. Please follow [this instruction](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/sql/virtual-machines-windows-portal-sql-server-provision) on how to provision a SQL Server virtual machine in the Azure Portal.

| Attribute  | Description |
|------------|-------------|
| SQL Server | DS15_V2 Standard |
| Processor  | Intel(R) Xeon(R) CPU E5-2673 v3 @ 2.40 GHz, **20 Cores** in total |
| Sockets    | 2 |
| Memory     | 140 GB |
| Disk Space | 280 GB SSD |

**NOTE: _The optimization on a SQL Server is hardware related. In this case, the optimization will be related to the number of CPUs and the number of (NUMA) Sockets._**

## Dataset and Data Schema

Three synthetic datasets were generated for the purpose of demonstrating the scenario. The first dataset is preprocessed resumes features. This dataset has 52 columns, which are PersonId, DocId (resume ID), and 50 topic features (from RT1 to RT50), and 1.1 million rows. The second dataset is the project (job) features which has 51 columns which are DocumentId and 50 topic columns (from PT1 to PT50) as well. The last dataset is a labeled dataset used for training. The labeled dataset only contains Label, DocId, and ProjectId columns. All those three datasets are available and free of downloading. The detailed information of these datasets is shown in the following table.

| Dataset  | Description | Download Link |
|------------|------------|---|
| Resume\_Features.csv | Resume feature dataset | [./Data/Resume_Features.csv](./Data/Resume_Features.csv) |
| Job\_Features.csv | Project (job) feature dataset | [./Data/Job_Features.csv](./Data/Job_Features.csv) |
| Labeled\_Data.csv | Training dataset | [./Data/Labled_Data.csv](./Data/Labled_Data.csv) |

## Enable to run R script within SQL query

In order to run R script within SQL query, we first need to enable this functionality. You can enable the R Services when you are provisioning the VM. If you forgot to do so, we are showing the detailed steps to enable SQL Server to run R code.

* **Step 1:** Run the following SQL query to explicitly enable the R Services feature on SQL Server; otherwise, it will not be possible to invoke R scripts even if the feature has been installed by setup.
    ```sql
    Exec sp_configure 'external scripts enabled', 1
    Reconfigure with override
    ```
* **Step 2:** Restart the SQL server for the SQL Server instance.

* **Step 3:** Verify that the R feature is enabled by running the following command and checking that the returning value is set to 1.
    ```sql
    Exec sp_configure 'external scripts enabled'
    ```

* **Step 4:** Run a simple R scripts like the following in SQL Server Management Studio.
    ```sql
    exec sp_execute_external_script @language =N'R',
    @script=N'OutputDataSet<-InputDataSet',
    @input_data_1 =N'select 1 as hello'
    with result sets (([hello] int not null));
    go
    ```

## Enable Implied Authentication for Launchpad Accounts

During setup of the SQL Server, 20 new Windows user accounts are created for the purpose of running tasks under the security token of the SQL Server Trusted Launchpad service. You can view these accounts in the Windows user group, SQLRUserGroup. However, if you need to run R scripts from a remote data science client and are using Windows authentication, these worker accounts must be given permission to log into the SQL Server instance on your behalf. We list the detailed steps to enable it.

* **Step 1:** In SQL Server Management Studio, in Object Explorer, expand Security, right-click Logins, and select New Login.

* **Step 2:** In the Login - New dialog box, click Search.

* **Step 3:** Click Object Types and select Groups. Deselect everything else.

* **Step 4:** In Enter the object name to select, type SQLRUserGroup and click Check Names.

* **Step 5:** The name of the local group associated with the instance's Launchpad service should resolve to something like instancename\SQLRUserGroup. Click OK.

* **Step 6:** By default, the login is assigned to the public role and has permission to connect to the database engine.

* **Step 7:** Click OK.

## Implementation

In this section, we will describe in great detail of the implementation on a SQL Server 2016 with R Services to handle the resume matching problem. The implementation includes the optimizations that have been applied on this specific machine, R code to train a matching model, to use the matching model, and a PowerShell script to launch multiple batch scoring concurrently. All those components are organized in the format of a few SQL scripts. Those scripts are used to configure the SQL server, optimize the server for this data science scenario, train the prediction model and score for each project (job). All those scripts are placed under the "***SQLR***" folder.

We will describe the implementation step by step and show the SQL queries as well.

### **Create Database and Tables**

We first need to create the database and tables for this problem. In total, we will create 6 tables. We describe the detail of those tables as follows.

| Table  | #Columns | Description |
|------------|------------|---|
| _dbo.Resumes_ | 52 | Table used to store all resume features |
| _dbo.Projects_ | 51 | Table used to store all project (job) features |
| _dbo.LabeledData_ | 3 | The labled training dataset (Only IDs, raw features not included) |
| _dbo.ClassificationModelR_ | 2 | Trained R model for matching |
| _dbo.PredictionsR_ | 5 | Table used to store all good matches |
| _dbo.scoring\_stats_ | 8 | Scoring statistics |

The SQL query can be found in file "***step1_create_database_and_tables.sql***" under "***SQLR***" folder. The first optimization applied in this tutorial is memory optimized tables. We created three memory-optimized tables (full durable) such that we can leverage the performance optimization using memory. Please pay attention to the "**WITH (MEMORY\_OPTIMIZED=ON)**" clause when creating _dbo.Resumes_, _dbo.Projects_, and _dbo.PredictionsR_ tables. Those three tables were configurated as memory optimized. On SQL Server, before you can create a memory-optimized table you will need to create a FILEGROUP that you declare CONTAINS MEMORY\_OPTIMIZED\_DATA. In this instruction, the file group is created under F drive. There is a folder '**F:\\Data**' created to save the data in the SQL script. Please change it accordingly when you run the SQL script below.

Those memory optimized tables help improve performance of OLTP applications through efficient, memory-optimized data access. The primary store for memory-optimized tables is main memory that rows in the table are read from and written to memory. The entire table resides in memory. While a second copy of the table data is maintained on disk, but only for durability purposes. Detailed information please refer to this [Introduction to Memory-Optimized Tables](https://docs.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/introduction-to-memory-optimized-tables).

```sql
USE master
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
SET NOCOUNT ON
GO


--Delete the database if it exists.
IF DB_ID('ResumeMatching') IS NOT NULL
	DROP DATABASE ResumeMatching
GO

--Create a new database called ResumeMatching
CREATE DATABASE ResumeMatching
GO

-- Enable Query Store before native module compilation
ALTER DATABASE ResumeMatching SET QUERY_STORE = ON;
GO 

--Create tables in RRA database
USE ResumeMatching
GO

--Memory optimized configurations
ALTER DATABASE CURRENT SET MEMORY_OPTIMIZED_ELEVATE_TO_SNAPSHOT = ON
GO
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 130
GO

--Change the file group path accordingly
ALTER DATABASE ResumeMatching ADD FILEGROUP imoltp_mod CONTAINS MEMORY_OPTIMIZED_DATA
ALTER DATABASE ResumeMatching ADD FILE (name='imoltp_mod1', filename='F:\Data\imoltp_mod1') TO FILEGROUP imoltp_mod

DROP TABLE IF EXISTS dbo.Resumes
GO

CREATE TABLE dbo.Resumes
(
	PersonId bigint NOT NULL PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT=100000),
	DocId bigint NOT NULL,
	RT1 float NOT NULL DEFAULT 0.0,
	RT2 float NOT NULL DEFAULT 0.0,
	RT3 float NOT NULL DEFAULT 0.0,
	RT4 float NOT NULL DEFAULT 0.0,
	RT5 float NOT NULL DEFAULT 0.0,
	RT6 float NOT NULL DEFAULT 0.0,
	RT7 float NOT NULL DEFAULT 0.0,
	RT8 float NOT NULL DEFAULT 0.0,
	RT9 float NOT NULL DEFAULT 0.0,
	RT10 float NOT NULL DEFAULT 0.0,
	RT11 float NOT NULL DEFAULT 0.0,
	RT12 float NOT NULL DEFAULT 0.0,
	RT13 float NOT NULL DEFAULT 0.0,
	RT14 float NOT NULL DEFAULT 0.0,
	RT15 float NOT NULL DEFAULT 0.0,
	RT16 float NOT NULL DEFAULT 0.0,
	RT17 float NOT NULL DEFAULT 0.0,
	RT18 float NOT NULL DEFAULT 0.0,
	RT19 float NOT NULL DEFAULT 0.0,
	RT20 float NOT NULL DEFAULT 0.0,
	RT21 float NOT NULL DEFAULT 0.0,
	RT22 float NOT NULL DEFAULT 0.0,
	RT23 float NOT NULL DEFAULT 0.0,
	RT24 float NOT NULL DEFAULT 0.0,
	RT25 float NOT NULL DEFAULT 0.0,
	RT26 float NOT NULL DEFAULT 0.0,
	RT27 float NOT NULL DEFAULT 0.0,
	RT28 float NOT NULL DEFAULT 0.0,
	RT29 float NOT NULL DEFAULT 0.0,
	RT30 float NOT NULL DEFAULT 0.0,
	RT31 float NOT NULL DEFAULT 0.0,
	RT32 float NOT NULL DEFAULT 0.0,
	RT33 float NOT NULL DEFAULT 0.0,
	RT34 float NOT NULL DEFAULT 0.0,
	RT35 float NOT NULL DEFAULT 0.0,
	RT36 float NOT NULL DEFAULT 0.0,
	RT37 float NOT NULL DEFAULT 0.0,
	RT38 float NOT NULL DEFAULT 0.0,
	RT39 float NOT NULL DEFAULT 0.0,
	RT40 float NOT NULL DEFAULT 0.0,
	RT41 float NOT NULL DEFAULT 0.0,
	RT42 float NOT NULL DEFAULT 0.0,
	RT43 float NOT NULL DEFAULT 0.0,
	RT44 float NOT NULL DEFAULT 0.0,
	RT45 float NOT NULL DEFAULT 0.0,
	RT46 float NOT NULL DEFAULT 0.0,
	RT47 float NOT NULL DEFAULT 0.0,
	RT48 float NOT NULL DEFAULT 0.0,
	RT49 float NOT NULL DEFAULT 0.0,
	RT50 float NOT NULL DEFAULT 0.0,

	INDEX IX_PersonId HASH (PersonId) with (BUCKET_COUNT=10000)
) WITH (MEMORY_OPTIMIZED=ON)
GO 


DROP TABLE IF EXISTS dbo.Projects
GO

CREATE TABLE dbo.Projects
(
	ProjectId bigint NOT NULL PRIMARY KEY NONCLUSTERED HASH WITH (BUCKET_COUNT=100000),
	PT1 float NOT NULL DEFAULT 0.0,
	PT2 float NOT NULL DEFAULT 0.0,
	PT3 float NOT NULL DEFAULT 0.0,
	PT4 float NOT NULL DEFAULT 0.0,
	PT5 float NOT NULL DEFAULT 0.0,
	PT6 float NOT NULL DEFAULT 0.0,
	PT7 float NOT NULL DEFAULT 0.0,
	PT8 float NOT NULL DEFAULT 0.0,
	PT9 float NOT NULL DEFAULT 0.0,
	PT10 float NOT NULL DEFAULT 0.0,
	PT11 float NOT NULL DEFAULT 0.0,
	PT12 float NOT NULL DEFAULT 0.0,
	PT13 float NOT NULL DEFAULT 0.0,
	PT14 float NOT NULL DEFAULT 0.0,
	PT15 float NOT NULL DEFAULT 0.0,
	PT16 float NOT NULL DEFAULT 0.0,
	PT17 float NOT NULL DEFAULT 0.0,
	PT18 float NOT NULL DEFAULT 0.0,
	PT19 float NOT NULL DEFAULT 0.0,
	PT20 float NOT NULL DEFAULT 0.0,
	PT21 float NOT NULL DEFAULT 0.0,
	PT22 float NOT NULL DEFAULT 0.0,
	PT23 float NOT NULL DEFAULT 0.0,
	PT24 float NOT NULL DEFAULT 0.0,
	PT25 float NOT NULL DEFAULT 0.0,
	PT26 float NOT NULL DEFAULT 0.0,
	PT27 float NOT NULL DEFAULT 0.0,
	PT28 float NOT NULL DEFAULT 0.0,
	PT29 float NOT NULL DEFAULT 0.0,
	PT30 float NOT NULL DEFAULT 0.0,
	PT31 float NOT NULL DEFAULT 0.0,
	PT32 float NOT NULL DEFAULT 0.0,
	PT33 float NOT NULL DEFAULT 0.0,
	PT34 float NOT NULL DEFAULT 0.0,
	PT35 float NOT NULL DEFAULT 0.0,
	PT36 float NOT NULL DEFAULT 0.0,
	PT37 float NOT NULL DEFAULT 0.0,
	PT38 float NOT NULL DEFAULT 0.0,
	PT39 float NOT NULL DEFAULT 0.0,
	PT40 float NOT NULL DEFAULT 0.0,
	PT41 float NOT NULL DEFAULT 0.0,
	PT42 float NOT NULL DEFAULT 0.0,
	PT43 float NOT NULL DEFAULT 0.0,
	PT44 float NOT NULL DEFAULT 0.0,
	PT45 float NOT NULL DEFAULT 0.0,
	PT46 float NOT NULL DEFAULT 0.0,
	PT47 float NOT NULL DEFAULT 0.0,
	PT48 float NOT NULL DEFAULT 0.0,
	PT49 float NOT NULL DEFAULT 0.0,
	PT50 float NOT NULL DEFAULT 0.0, 

	INDEX IX_ProjectId HASH (ProjectId) WITH (BUCKET_COUNT=10000)
) WITH (MEMORY_OPTIMIZED=ON)
GO 

DROP TABLE IF EXISTS dbo.LabeledData
GO

CREATE TABLE dbo.LabeledData
(
	Label tinyint NOT NULL,
	DocId bigint NOT NULL,
	ProjectId bigint NOT NULL
)
GO

DROP TABLE IF EXISTS dbo.ClassificationModelR
GO

CREATE TABLE dbo.ClassificationModelR
(
	modelName varchar(100) not null,
	model varbinary(max) not null
)
GO

DROP TABLE IF EXISTS dbo.PredictionsR
GO

CREATE TABLE dbo.PredictionsR
(
	[id] bigint IDENTITY(1,1) PRIMARY KEY NONCLUSTERED, 
	[PersonId] [bigint] NOT NULL,
	[DocId] [bigint] NOT NULL,
	[ProjectId] [bigint] NOT NULL,
	[Probability] [float] NOT NULL,
) WITH (MEMORY_OPTIMIZED=ON, DURABILITY=SCHEMA_AND_DATA)
GO

DROP TABLE IF EXISTS dbo.scoring_stats
GO

CREATE TABLE dbo.scoring_stats
(
	project_id bigint NOT NULL,
	group_id int NOT NULL,
	match_row_count int NOT NULL,
	start_time datetime2 NOT NULL,
	end_time datetime2 NOT NULL,
	r_predict_duration float NOT NULL,
	total_duration float NOT NULL,
	rate_prediction float NOT NULL
)
GO
```

### **Load Dataset**

We can directly download the datasets and store all those datasets into SQL talbes by executing the following SQL query. The details can be found in SQL script "***step2_load_data.sql***". And we are assuming you have downloaded all 3 csv files under folder "**C:\\resumematching\\Data\\**". _Please note that if you put those csv files under your home folder, SQL Server will NOT have access to read those files since SQL threads are under a special user group_.

```sql
USE ResumeMatching
GO

INSERT INTO [dbo].[Projects]
EXEC sp_execute_external_script 
@language = N'R',
@script = N'OutputDataSet <- read.csv(file=file.path("C:\\resumematching\\Data\\", "Job_Features.csv"), h=T, sep=",")'


INSERT INTO [dbo].[Resumes]
EXEC sp_execute_external_script 
@language = N'R',
@script = N'OutputDataSet <- read.csv(file=file.path("C:\\resumematching\\Data\\", "Resume_Features.csv"), h=T, sep=",")'


INSERT INTO [dbo].[LabeledData]
EXEC sp_execute_external_script 
@language = N'R',
@script = N'OutputDataSet <- read.csv(file=file.path("C:\\resumematching\\Data\\", "Labled_Data.csv"), h=T, sep=",")'
```

### **SQL Server Optimizations**

The SQL Server optimizations is the key to handle this problem. Those optimizations can be find in the SQL query file ***step3_optimizations.sql*** under ***SQLR*** folder. We will only show the steps of those optimizations and configurations but not include the technical details of those optimizations.

#### **Step 1: Set up Soft-NUMA**

We will first setup soft-NUMA to enable the ability to partition service threads per NUMA node. And it generally increases scalability and performance by reducing IO and lazy writer bottlenecks on computers with many CPUs and no hardware NUMA. The SQL Server we used is a 20 cores Azure SQL Server 2016 with R Services, which has 2 NUMA sockets and each socket contains 10 cores.

```sql
-- Step 1: Setup Soft-NUMA
alter server configuration
set process affinity numanode = 0 to 1
```

By default, SQL Server will use soft affinity and as a result the OS can move SQL threads to any CPU which may resulting unpredictability. This configuration will configure the SQL Server using hard affinity and improve the performance. This '[Understanding Non-uniform Memory Access](https://msdn.microsoft.com/en-us/library/ms178144.aspx)' blog will help you to better understand NUMA nodes.

#### **Step 2: Determine the CPUs to be allocated per resource pool**

The next step is to split the large number of CPUs on the machine into 4 buckets that each bucket containing 5 CPUs from the same NUMA node. The purpose of doing this is to reduce foreign memory access such that the performance can be improved. The number of buckets and CPUs were chosen based on the hardware. Since the SQL server we have provisioned has 2 NUMA nodes that each node consists of 10 CPUs, we decided to further divide each NUMA node into 2 buckets. There are multiple configurations to allocate those CPUs. We can split 20 cores into 2 buckets (10 cores per bucket), 4 buckets (5 cores per bucket), and 10 buckets (2 cores per bucket). And our test shows that with 4 bucket give us the best performance in this use case. If the hardware you are using is different then you may need to experiment what is the best configuration in your case.

The query below can be used to determine the CPUs to be allocated per bucket:

```sql
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
```

By executing this query, we get the following results:

| bucket | scheduler_range | min\_cpu | max\_cpu |
|--------|-----------------|----------|----------|
| 0	| 0,1,2,3,4	| 0	| 4 |
| 1	| 5,6,7,8,9	| 5	| 9 |
| 2	| 10,11,12,13,14 | 10 | 14 |
| 3	| 15,16,17,18,19 | 15 | 19 |

#### **Step 3: Create resource pools for workload groups**

We will create 4 internal and 4 external resource pools that each resource pool will be associated with a workload group. Those resource pool will be assigned with different CPUs. In addition, we also need to configure the memory allocation for both internal and external use. In our test, we set the maximum internal memory usage to be 30% (70% max of memory could be used by R sessions) and it achieved best performance.

```sql
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
```

And you can check the resource pool configuration by running the following query:
```sql
SELECT * FROM sys.resource_governor_workload_groups;
SELECT * FROM sys.resource_governor_resource_pools;
SELECT * FROM sys.resource_governor_external_resource_pools;
SELECT * FROM sys.resource_governor_external_resource_pool_affinity;
```

#### **Step 4: Create and assign workload group to resource pools**

We next need to create 4 workload groups that each workload group is associated with a resource pool. Those workload groups were also assigned with specific names such that we can use the names to assign different tasks to different workload groups.

```sql
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
```

#### **Step 5: Create UDF to route workload group**

SQL Server supports a feature called Resource Governor that we can used to manage SQL Server workload and system resource consumption. This feature enables us to better manager the resources on SQL server by specifying limits on resource consumption by incoming requests. Hereafter is a figure shows all components and their relationship with each other as they exist in the SQL Server.

The first thing we need to do is to define a User-defined classifier function (UDF) to assign different tasks on different workload groups. In this use case, all scoring tasks will be labeled with an application name in the format of "[number] - PredictionJob", for instance "_2 - PredictionJob_", and the UDF will parse the application name and assign it to an appropriate workload group which will assign "_2 - PredictionJob_" to workload group "_wg2_".

```sql
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
```

#### **Step 6: Enable Resource Governer with UDF classifier**

After we have created the UDF to assign scoring tasks to workload groups, the next step is to enable Resource Governor option on SQL Server using the following SQL query:

```sql
-- Step 6: Enable Resource Governer with UDF classifier
ALTER RESOURCE GOVERNOR
WITH (CLASSIFIER_FUNCTION=dbo.assign_workload_group);
GO
ALTER RESOURCE GOVERNOR RECONFIGURE
GO
```

## Train Prediction Model

The training dataset is a synthetic dataset which contains of 50,000 rows of data. The dataset includes 3 columns and this table can be joined with other tables in the SQL database to generate a 100 features dataset for training. We outline the training process as following steps.

1. Join tables to combine features from both resume and job

1. Train model (Gradient Boosted Decision Tree)

1. Store prediction model in database

The joined dataset is then used to train a Gradient Boosted Decision Tree model with 100 trees. The model is stored in the database with a specific name such that we can choose which model we want to use during prediction. We created a stored procedure "_train\_model\_for\_matching_" and we can call this procedure to train a prediction model. Detailed SQL query please refer to "***step4_train_model.sql***".

```sql
USE ResumeMatching
GO 

DROP PROCEDURE IF EXISTS train_model_for_matching;
GO

CREATE PROCEDURE train_model_for_matching (@model_name varchar(100))
AS
BEGIN
	DECLARE @inquery nvarchar(max) = N'select ld.Label';
	declare @topics int = 50;
	declare @i int = 1;
	declare @j int = 1;

	while (@i <= @topics)
	begin
		set @inquery += concat(N', r.RT', @i, N' as RT', @i);
		set @i = @i + 1
	end

	while (@j <= @topics)
	begin
		set @inquery += concat(N', p.PT', @j, N' as PT', @j);
		set @j = @j + 1
	end

	set @inquery += N' 
	from [dbo].[LabeledData] ld
	join [dbo].[Resumes] r
	on ld.DocId = r.DocId
	join [dbo].[Projects] p
	on ld.ProjectId = p.ProjectId'

	declare @trained_model varbinary(max)
	delete from [dbo].[ClassificationModelR] where [modelName] = @model_name
	EXEC sp_execute_external_script 
	@language = N'R',
	@script = N'
	input_dim = dim(InputDataSet) 
	print(paste("Input dataset:", input_dim[1], "rows,", input_dim[2], "columns"))

	library("RevoScaleR")

	feature_names <- setdiff(names(InputDataSet), c("Label"))
	myformula <- as.formula(paste("Label", paste(feature_names, collapse = " + "), sep = " ~ "))
	BTreeModel <- rxBTrees(formula = myformula,
				data = InputDataSet,
				learningRate = 0.2,
				minSplit = 10,
				minBucket = 10,
				nTree = 50,
				seed = 314159,
				lossFunction = "bernoulli",
				verbose = 0);

	print(BTreeModel)

	trained_model <- as.raw(serialize(BTreeModel, NULL));
	',
	@input_data_1 = @inquery,
	@params  = N'@trained_model varbinary(max) OUTPUT',
	@trained_model = @trained_model OUTPUT;

	INSERT INTO [dbo].[ClassificationModelR] values(@model_name, @trained_model);
END;
GO
```

We then train a prediction model by running the SQL query:
```sql
EXEC [dbo].[train_model_for_matching] "rxBTrees"
```

A prediction model named "_rxBTrees_" will be saved in table "_dbo.ClassificationModelR_".


## Prediction

The trained model can now be used to find the best candidates given a now job. The input data for the model will be a project (job) ID, and the model will generate the features for all resume-job pairs and use the trained prediction model for scoring.

One of the primary benefits of SQL Server is its ability to handle a very large volume of rows in parallel. We first split the matching into a few tasks and each workload group will process one task. Furthermore, SQL Server with R Services can query the database within the R code to perform selection, joining and aggregations in parallel as well. We also created a saved procedure for prediction. The detail of the query please refer to file "***step5_score_for_matching.sql***".

```sql
USE ResumeMatching
GO

DROP PROCEDURE IF EXISTS score_for_matching_batch;
GO

CREATE PROCEDURE score_for_matching_batch (
	@model_name varchar(100),
	@projectid bigint,
	@start int,
	@end int,
	@threshold float
)
AS
BEGIN
	set nocount on;

	declare @start_time datetime2 = SYSDATETIME(), @predict_duration float, @match_row_count int;
	declare @baseid int = (select min([PersonId]) from [dbo].[Resumes]);
	
	declare @topics int = 50;
	declare @i int = 1;
	declare @j int = 1;

	declare @inquery nvarchar(max) = N'select PersonId, DocId, ProjectId';
	while (@i <= @topics)
	begin
		set @inquery += concat(N', r.RT', @i, N' as RT', @i);
		set @i = @i + 1
	end
	while (@j <= @topics)
	begin
		set @inquery += concat(N', p.PT', @j, N' as PT', @j);
		set @j = @j + 1
	end
	set @inquery += concat(N' 
	from [dbo].[Resumes] r, [dbo].[Projects] p 
	where ProjectId = ', @projectid, 
	N'and r.personId between ', @start+@baseid, N' and ', @end+@baseid,
	N'option(maxdop 8)')

	DECLARE @modelr varbinary(max) = (select model from [dbo].[ClassificationModelR] where [modelName]=@model_name);

	INSERT INTO [dbo].[PredictionsR] (Probability, PersonId, DocId, ProjectId)
	EXEC sp_execute_external_script 
	@language = N'R',
	@script = N'
	library("RevoScaleR")

	topic_num <- 50
	mod <- unserialize(as.raw(model));

	predict_duration <- system.time(pred_scores <- rxPredict(mod, 
		InputDataSet, 
		type="prob", 
		predVarNames="Probability", 
		extraVarsToWrite=c("PersonId", "DocId", "ProjectId"),
		reportProgress=0, 
		verbose=0))[3]
	OutputDataSet <- subset(pred_scores, Probability >= threshold)
	',
	
	@input_data_1 = @inquery,
	@output_data_1_name = N'OutputDataSet',
	@params = N'@model varbinary(max), @projectid bigint, @start int, @end int, @threshold float, @predict_duration float OUTPUT',
	@model = @modelr,
	@projectid = @projectid,
	@start = @start,
	@end = @end,
	@threshold = @threshold,
	@predict_duration = @predict_duration OUTPUT;

	set @match_row_count = @@ROWCOUNT;
	insert into [dbo].[scoring_stats] ([project_id], [group_id], [match_row_count], [start_time], [end_time], [r_predict_duration], [total_duration], [rate_prediction]) 
	select @projectid, group_id, @match_row_count, @start_time, SYSDATETIME(), @predict_duration, DATEDIFF_BIG(ms, @start_time, SYSDATETIME())/1000.0, (@end-@start)*1000./DATEDIFF_BIG(ms, @start_time, SYSDATETIME())
	from sys.dm_exec_sessions as s
	where s.session_id = @@SPID;

	print concat('Resume matching duration: ', DATEDIFF_BIG(ms, @start_time, SYSDATETIME()), ' ms
	Rate of prediction: ', (@end-@start)*1000./DATEDIFF_BIG(ms, @start_time, SYSDATETIME()), ' per second
	Predict duration: ', @predict_duration, ' sec
	Found matches: ', @match_row_count);

END
```

This script will create a saved procedure called "score\_for\_matching\_batch".

## Concurrent Scoring

We created a PowerShell script to use the Invoke-SqlCmd cmdlet to execute multiple concurrent scoring tasks. Since we have divided 20 CPUs into 4 buckets that each bucket contains 5 CPUs on the same NUMA node, the maximum concurrent is set to 8. In another word, each workload group will need to handle 2 scoring tasks. The reason we double the concurrent tasks is that when one task is finishing reading data and start scoring, the other one can start reading data from database.

The PowerShell code called "***experiment.ps1***" can be found in the "***SQLR***" folder as well. And hereafter we are showing the code how to initiate the scoring tasks in parallel with a specific application name. **Please note that you will need to update the _vServerName_ variable (it's been named 'SQLRTUTORIAL' here) accordingly to run the script on your machine**. The script will also use the previous trained model *_rxBTrees_*. So if you have changed your model name, please change it here as well.

```bash
$count = 1
$TotalRows = 1100000
$vServerName = "SQLRTUTORIAL"
$vDatabaseName = "ResumeMatching"

$num_workload_group = 4
$batch_per_load = 2
$model = "rxBTrees"
$projectId = 1000001

$Start = 0
$Increment = $TotalRows/($num_workload_group*$batch_per_load)
$End = $Start+$Increment-1
$EndCtr = 0


Write-Host "Starting the prediction jobs for Project [$projectId]..."
while (($EndCtr -le $TotalRows) -and ($count -le $num_workload_group))
{
    # Set application name for SQLCMD command using the loop counter.
    # In SQL Server side, the resource governor classifier function will
    # assign the correct workload group (which represents a resource pool and
    # external resource pool pair)
    [string] $AppName = "$count - PredictionJob"

    # Generate two script blocks containing the SQLCMD command.
    # The wrapper stored procedure simply invokes the scoring procedure in a loop.
    $SqlScript = [ScriptBlock]::Create("Invoke-SqlCmd -Server `"" + $vServerName + "`" -Query `"EXEC score_for_matching_batch " + $model + ", " + $projectId + ", " + $Start + ", " + $End + ", 0.51`" -Database `"$vDatabaseName`" -QueryTimeout 0 -HostName `"$AppName`"")
    Start-Job -ScriptBlock $SqlScript
    $EndCtr += $Increment
    $Start += $Increment
    $End += $Increment

    if ($batch_per_load -ge 2) {
        $SqlScript = [ScriptBlock]::Create("Invoke-SqlCmd -Server `"" + $vServerName + "`" -Query `"EXEC score_for_matching_batch " + $model + ", " + $projectId + ", " + $Start + ", " + $End + ", 0.51`" -Database `"$vDatabaseName`" -QueryTimeout 0 -HostName `"$AppName`"")
        Start-Job -ScriptBlock $SqlScript
        $EndCtr += $Increment
        $Start += $Increment
        $End += $Increment
    }

    if ($batch_per_load -ge 3) {
        $SqlScript = [ScriptBlock]::Create("Invoke-SqlCmd -Server `"" + $vServerName + "`" -Query `"EXEC score_for_matching_batch " + $model + ", " + $projectId + ", " + $Start + ", " + $End + ", 0.51`" -Database `"$vDatabaseName`" -QueryTimeout 0 -HostName `"$AppName`"")
        Start-Job -ScriptBlock $SqlScript
        $EndCtr += $Increment
        $Start += $Increment
        $End += $Increment
    }

    if ($batch_per_load -ge 4) {
        $SqlScript = [ScriptBlock]::Create("Invoke-SqlCmd -Server `"" + $vServerName + "`" -Query `"EXEC score_for_matching_batch " + $model + ", " + $projectId + ", " + $Start + ", " + $End + ", 0.51`" -Database `"$vDatabaseName`" -QueryTimeout 0 -HostName `"$AppName`"")
        Start-Job -ScriptBlock $SqlScript
        $EndCtr += $Increment
        $Start += $Increment
        $End += $Increment
    }

    if ($batch_per_load -ge 5) {
        $SqlScript = [ScriptBlock]::Create("Invoke-SqlCmd -Server `"" + $vServerName + "`" -Query `"EXEC score_for_matching_batch " + $model + ", " + $projectId + ", " + $Start + ", " + $End + ", 0.51`" -Database `"$vDatabaseName`" -QueryTimeout 0 -HostName `"$AppName`"")
        Start-Job -ScriptBlock $SqlScript
        $EndCtr += $Increment
        $Start += $Increment
        $End += $Increment
    }

    $count += 1
}
```

## Get Results

After running the PowerShell script to find best matches for an open job, all results will be write back to the database. In addition, we also write back the statistics of the prediction into table "***dbo.scoring_stats***". A SQL script ***step6_scoring_stats.sql*** is created to query the running statistic result.

```sql
declare @pid bigint = 1000001

select project_id, datediff_big(ms, min(start_time), max(end_time))/1000.0 as duration from [dbo].[scoring_stats]
where project_id = @pid
group by project_id

select * from [dbo].[scoring_stats] where project_id = @pid
```

The first select query will show you the total duration for scoring 1.1 million rows of data. While the second select query provides the details of 8 batch executions.

## Conclusion

SQL Server 2016 with R Service provides a scalable solution to handle the resume matching use case. In this tutorial, we used in-memory table, soft-NUMA, resource pool, and resource governance techniques to optimize the computation on SQL server. By applying those optimization techniques, we have achieved to score **1.1 million** rows of data (with 100 features) within **8.5 seconds** on a 20 cores machine.

## Useful References

[Configure and Manage Advanced Analytics Extensions](https://msdn.microsoft.com/en-US/library/mt590869.aspx)

[Set up SQL Server R Services (In-Database)](https://msdn.microsoft.com/en-us/library/mt696069.aspx)

[Use sqlBindR.exe to Upgrade an Instance of R Services](https://msdn.microsoft.com/en-US/library/mt791781.aspx)

[Recommendations and guidelines for the "max degree of parallelism" configuration option in SQL Server](https://support.microsoft.com/en-us/kb/2806535)

[Resource Governance for R Services](https://msdn.microsoft.com/en-us/library/mt703708.aspx)

[How to: Configure SQL Server to Use Soft-NUMA](https://technet.microsoft.com/en-us/library/ms345357(v=sql.105).aspx)

[Resource Governor](https://msdn.microsoft.com/en-us/library/bb933866.aspx)

[SQL SERVER – Simple Example to Configure Resource Governor – Introduction to Resource Governor](http://blog.sqlauthority.com/2012/06/04/sql-server-simple-example-to-configure-resource-governor-introduction-to-resource-governor/)

[How To: Create a Resource Pool for R](https://msdn.microsoft.com/en-us/library/mt703706.aspx)
