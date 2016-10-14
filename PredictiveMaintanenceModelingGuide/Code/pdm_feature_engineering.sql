--This SQL script does the feature engineering for the datasets you uploaded in the previous step

--telemetry data
DROP TABLE IF EXISTS telemetrymean
GO

create table telemetrymean
(
	datetime datetime,
	machineID numeric,
	voltmean float,
	rotatemean float,
	pressuremean float,
	vibrationmean float	
	)

-- calculate the rolling mean and rolling standard deviation for telemetry data
-- rows 2 preceding is short hand for ROWS 2 PRECEDING AND CURRENT ROW which is equivalent to by = 3
insert into telemetrymean 
select rt.datetime, rt.machineID, rt.voltmean, rt.rotatemean, rt.pressuremean, rt.vibrationmean
from 
(select avg(volt) over(partition by machineID order by machineID, datetime rows 2 preceding) as voltmean,
        avg(rotate) over(partition by machineID order by machineID, datetime rows 2 preceding) as rotatemean,
        avg(pressure) over(partition by machineID order by machineID, datetime rows 2 preceding) as pressuremean,
        avg(vibration) over(partition by machineID order by machineID, datetime rows 2 preceding) as vibrationmean,
        row_number() over (partition by machineID order by machineID, datetime) as rn,
        machineID, datetime
from telemetry) rt
where rt.rn % 3 = 0 and rt.voltmean is not null
order by rt.machineID, rt.datetime

select top 10 * from telemetrymean order by machineID, datetime

--select top 10 * from telemetrymean where machineID=2 order by machineID, datetime


DROP TABLE IF EXISTS telemetrysd
GO

create table telemetrysd
(
	datetime datetime,
	machineID numeric,
	voltsd float,
	rotatesd float,
	pressuresd float,
	vibrationsd float	
	)

insert into telemetrysd
select rt.datetime, rt.machineID, rt.voltsd, rt.rotatesd, rt.pressuresd, rt.vibrationsd
from 
(select stdev(volt) over(partition by machineID order by machineID, datetime rows 2 preceding) as voltsd,
        stdev(rotate) over(partition by machineID order by machineID, datetime rows 2 preceding) as rotatesd,
        stdev(pressure) over(partition by machineID order by machineID, datetime rows 2 preceding) as pressuresd,
        stdev(vibration) over(partition by machineID order by machineID, datetime rows 2 preceding) as vibrationsd,
        row_number() over (partition by machineID order by machineID, datetime) as rn,
        machineID, datetime
from telemetry) rt
where rt.rn % 3 = 0 and rt.voltsd is not null
order by rt.machineID, rt.datetime

select top 10 * from telemetrysd order by machineID, datetime

select top 10 * from telemetrysd where machineID=2 order by machineID, datetime

DROP TABLE IF EXISTS telemetrymean_24hrs
GO

create table telemetrymean_24hrs
(
	datetime datetime,
	machineID numeric,
	voltmean_24hrs float,
	rotatemean_24hrs float,
	pressuremean_24hrs float,
	vibrationmean_24hrs float	
	)


insert into telemetrymean_24hrs 
select rt.datetime, rt.machineID, rt.voltmean_24hrs, rt.rotatemean_24hrs, rt.pressuremean_24hrs, rt.vibrationmean_24hrs
from 
(select avg(volt) over(partition by machineID order by machineID, datetime rows 23 preceding) as voltmean_24hrs,
        avg(rotate) over(partition by machineID order by machineID, datetime rows 23 preceding) as rotatemean_24hrs,
        avg(pressure) over(partition by machineID order by machineID, datetime rows 23 preceding) as pressuremean_24hrs,
        avg(vibration) over(partition by machineID order by machineID, datetime rows 23 preceding) as vibrationmean_24hrs,
        row_number() over (partition by machineID order by machineID, datetime) as rn,
        machineID, datetime
from telemetry) rt
where rt.rn % 3 = 0 and rt.voltmean_24hrs is not null
order by rt.machineID, rt.datetime

select top 10 * from telemetrymean_24hrs order by machineID, datetime

select top 10 * from telemetrymean_24hrs where machineID=2 order by machineID, datetime


DROP TABLE IF EXISTS telemetrysd_24hrs
GO

create table telemetrysd_24hrs
(
	datetime datetime,
	machineID numeric,
	voltsd_24hrs float,
	rotatesd_24hrs float,
	pressuresd_24hrs float,
	vibrationsd_24hrs float	
	)

insert into telemetrysd_24hrs
select rt.datetime, rt.machineID, rt.voltsd_24hrs, rt.rotatesd_24hrs, rt.pressuresd_24hrs, rt.vibrationsd_24hrs
from 
(select stdev(volt) over(partition by machineID order by machineID, datetime rows 23 preceding) as voltsd_24hrs,
        stdev(rotate) over(partition by machineID order by machineID, datetime rows 23 preceding) as rotatesd_24hrs,
        stdev(pressure) over(partition by machineID order by machineID, datetime rows 23 preceding) as pressuresd_24hrs,
        stdev(vibration) over(partition by machineID order by machineID, datetime rows 23 preceding) as vibrationsd_24hrs,
        row_number() over (partition by machineID order by machineID, datetime) as rn,
        machineID, datetime
from telemetry) rt
where rt.rn % 3 = 0 and rt.voltsd_24hrs is not null
order by rt.machineID, rt.datetime

select top 10 * from telemetrysd_24hrs order by machineID, datetime

select top 10 * from telemetrysd_24hrs where machineID=2 order by machineID, datetime


-- Merge the 4 tables into telemetryfeat 
DROP TABLE IF EXISTS telemetryfeat
GO

DROP TABLE IF EXISTS telemetryfeat_3hrs
GO

DROP TABLE IF EXISTS telemetryfeat_24hrs
GO

select tm3.datetime, tm3.machineID, 
tm3.voltmean, tm3.rotatemean,tm3.pressuremean,tm3.vibrationmean, 
ts3.voltsd, ts3.rotatesd, ts3.pressuresd, ts3.vibrationsd 
into telemetryfeat_3hrs
from telemetrymean tm3 left join telemetrysd ts3 
on tm3.datetime =ts3.datetime and tm3.machineId =ts3.machineId 
order by tm3.machineID asc, ts3.datetime asc

select top 10 * from telemetryfeat_3hrs

select tm24.datetime, tm24.machineID, 
tm24.voltmean_24hrs, tm24.rotatemean_24hrs,tm24.pressuremean_24hrs,tm24.vibrationmean_24hrs, 
ts24.voltsd_24hrs, ts24.rotatesd_24hrs, ts24.pressuresd_24hrs, ts24.vibrationsd_24hrs 
into telemetryfeat_24hrs
from telemetrymean_24hrs tm24 left join telemetrysd_24hrs ts24 
on tm24.datetime =ts24.datetime and tm24.machineId =ts24.machineId 
order by tm24.machineID asc, ts24.datetime asc

select top 10 * from telemetryfeat_24hrs

select tf3.datetime, tf3.machineID, 
tf3.voltmean, tf3.rotatemean, tf3.pressuremean, tf3.vibrationmean, 
tf3.voltsd, tf3.rotatesd, tf3.pressuresd, tf3.vibrationsd ,
tf24.voltmean_24hrs, tf24.rotatemean_24hrs, tf24.pressuremean_24hrs, tf24.vibrationmean_24hrs, 
tf24.voltsd_24hrs, tf24.rotatesd_24hrs, tf24.pressuresd_24hrs, tf24.vibrationsd_24hrs 
into telemetryfeat
from telemetryfeat_3hrs tf3 left join telemetryfeat_24hrs tf24
on tf3.datetime =tf24.datetime and tf3.machineId =tf24.machineId 
order by tf3.machineID asc, tf3.datetime asc

select top 10 * from telemetryfeat order by machineID, datetime

select top 10 * from telemetryfeat where machineID=2 order by machineID, datetime


-- error data--
drop table if exists errorcount
-- create the binary table for errors per counter
select datetime, machineID, sum(error1) as error1, sum(error2) as error2, sum(error3) as error3, sum(error4) as error4, sum(error5) as error5 
into errorcount
from 
(select datetime, machineID, errorID,
	case when errorID = 'error1' then 1 else 0 end as error1,
	case when errorID = 'error2' then 1 else 0 end as error2,
	case when errorID = 'error3' then 1 else 0 end as error3,
	case when errorID = 'error4' then 1 else 0 end as error4,   
	case when errorID = 'error5' then 1 else 0 end as error5   
from [dbo].[errors]) as bin 
group by datetime, machineID

select top 10 * from errorcount order by machineID, datetime

drop table if exists telemetryerror
--left join with telemetry and fill in NULL with 0 to prepare for sum
select tf.datetime, tf.machineID, 
ISNULL(ec.error1,0) as error1, ISNULL(ec.error2,0) as error2, 
ISNULL(ec.error3,0) as error3, ISNULL(ec.error4,0) as error4, 
ISNULL(ec.error5,0) as error5
into telemetryerror
from telemetry tf left join errorcount ec 
on tf.datetime=ec.datetime and tf.machineId=ec.machineID order by tf.machineID asc, tf.datetime asc

select top 10 * from telemetryerror where machineID=1

-- Sum for the last 24 hours into errorfeat
DROP TABLE IF EXISTS errorfeat
GO

create table errorfeat
(
	datetime datetime,
	machineID numeric,
	error1count float,
	error2count float,
	error3count float,
	error4count float,
	error5count float	
	)

insert into errorfeat
select rt.datetime, rt.machineID, rt.error1count, rt.error2count, rt.error3count, rt.error4count, rt.error5count 
from 
(select sum(error1) over(partition by machineID order by machineID, datetime rows 23 preceding) as error1count,
        sum(error2) over(partition by machineID order by machineID, datetime rows 23 preceding) as error2count,
		sum(error3) over(partition by machineID order by machineID, datetime rows 23 preceding) as error3count,
		sum(error4) over(partition by machineID order by machineID, datetime rows 23 preceding) as error4count,
		sum(error5) over(partition by machineID order by machineID, datetime rows 23 preceding) as error5count,
        row_number() over (partition by machineID order by machineID, datetime) as rn,
        machineID, datetime
from telemetryerror) rt
where rt.rn % 3 = 0 and rt.error1count is not null
order by rt.machineID, rt.datetime

select top 20 * from errorfeat order by machineID, datetime

select top 10 * from errorfeat where machineID=2 order by machineID, datetime


/******************* maint data*********************/
-- create the binary table for errors per counter
select datetime, machineID, comp,
	case when comp = 'comp1' then 1 else 0 end as comp1,
	case when comp = 'comp2' then 1 else 0 end as comp2,
	case when comp = 'comp3' then 1 else 0 end as comp3,
	case when comp = 'comp4' then 1 else 0 end as comp4
from [dbo].[maint]

--number of days since last component calculations
drop table if exists comp1
drop table if exists comp2
drop table if exists comp3
drop table if exists comp4

select t1.datetime, t1.machineId, min(coalesce(datediff(day, t2.datetime, t1.datetime), 0)) as sincelastcomp1
into comp1
from telemetryfeat as t1 left join maint t2
on t1.machineID=t2.machineID 
where t1.datetime > t2.datetime and t2.comp='comp1'
group by t1.datetime, t1.machineID

select t1.datetime, t1.machineId, min(coalesce(datediff(day, t2.datetime, t1.datetime), 0)) as sincelastcomp2
into comp2
from telemetryfeat as t1 left join maint t2
on t1.machineID=t2.machineID 
where t1.datetime > t2.datetime and t2.comp='comp2'
group by t1.datetime, t1.machineID

select t1.datetime, t1.machineId, min(coalesce(datediff(day, t2.datetime, t1.datetime), 0)) as sincelastcomp3
into comp3
from telemetryfeat as t1 left join maint t2
on t1.machineID=t2.machineID 
where t1.datetime > t2.datetime and t2.comp='comp3'
group by t1.datetime, t1.machineID

select t1.datetime, t1.machineId, min(coalesce(datediff(day, t2.datetime, t1.datetime), 0)) as sincelastcomp4
into comp4
from telemetryfeat as t1 left join maint t2
on t1.machineID=t2.machineID 
where t1.datetime > t2.datetime and t2.comp='comp4'
group by t1.datetime, t1.machineID

select top 10 * from comp1
select top 10 * from comp2
select top 10 * from comp3
select top 10 * from comp4

DROP TABLE IF EXISTS compfeat
GO

create table compfeat
(
	datetime datetime,
	machineID numeric,
	sincelastcomp1 float,
	sincelastcomp2 float,
	sincelastcomp3 float,
	sincelastcomp4 float	
	)

insert into compfeat 
select a.datetime, a.machineID, ISNULL(a.sincelastcomp1,0) as sincelastcomp1, 
ISNULL(a.sincelastcomp2,0) as sincelastcomp2, ISNULL(b.sincelastcomp3,0) as sincelastcomp3, 
ISNULL(b.sincelastcomp4,0) as sincelastcomp4
from 
(select t1.datetime, t1.machineID, t1.sincelastcomp1, t2.sincelastcomp2
from comp1 t1 left join comp2 t2
on t1.machineID=t2.machineID and t1.datetime=t2.datetime) a
left join 
(select t1.datetime, t1.machineID, t1.sincelastcomp3, t2.sincelastcomp4
from comp3 t1 left join comp4 t2
on t1.machineID=t2.machineID and t1.datetime=t2.datetime) b
on a.datetime=b.datetime and a.machineID=b.machineID

select top 10 * from compfeat order by machineID, datetime

select top 10 * from compfeat where machineID=2 order by machineID, datetime

select * from compfeat where sincelastcomp1 = ''

select distinct(sincelastcomp4), count(*) 
from compfeat 
group by sincelastcomp4

/******************* machine data*********************/
/******************* final feature data*********************/
-- left join telemetryfeat with, errorfeat, maintfeat and machine and just send features of the (last slice-24) hours 
drop table if exists finalfeat

--select top 10 * from telemetryfeat
--select top 10 * from errorfeat
--select top 10 * from compfeat where sincelastcomp1 = ''
--select top 10 * from machines

select tf.*, ef.error1count, ef.error2count, ef.error3count, ef.error4count, ef.error5count,  
ISNULL(cf.sincelastcomp1,0) as sincelastcomp1, 
ISNULL(cf.sincelastcomp2,0) as sincelastcomp2, ISNULL(cf.sincelastcomp3,0) as sincelastcomp3, 
ISNULL(cf.sincelastcomp4,0) as sincelastcomp4, m.model, m.age
into finalfeat
from telemetryfeat tf left join errorfeat ef on tf.machineId=ef.machineId and tf.datetime=ef.datetime
left join compfeat cf on  tf.machineId=cf.machineId and tf.datetime=cf.datetime left join machines m
on tf.machineId=m.machineId
order by  tf.machineId, tf.datetime

select top 10 * from finalfeat order by machineID, datetime 

select top 10 * from finalfeat where machineID=2 order by machineID, datetime 

select top 10 * from finalfeat where sincelastcomp1 = ''

--Cleaning up 
drop table if exists comp1
drop table if exists comp2
drop table if exists comp3
drop table if exists comp4
drop table if exists errorcount

/******************* label construction*********************/
-- left join final features with failures on machineID then mutate a column for datetime difference
-- filter date difference for the prediction horizon which is 24 hours
drop table if exists labeled

select a.datetime, a.machineID, a.failure 
into labeled
from 
(select ff.*, f.datetime as failure_date, datediff(hour, ff.datetime, f.datetime) as date_diff, f.failure 
from finalfeat ff left join failures f on ff.machineID=f.machineID) a
where a.date_diff >=0 and a.date_diff <=24

select top 10 * from labeled where machineID=1 order by machineID, datetime

-- left join labels to final features and fill NA's with "none" indicating no failure
drop table if exists labeledfeat

select a.datetime, a.machineID, a.voltmean, a.rotatemean, a.pressuremean, a.vibrationmean, a.voltsd, a.rotatesd, a.pressuresd, a.vibrationsd,
a.voltmean_24hrs, a.rotatemean_24hrs, a.pressuremean_24hrs, a.vibrationmean_24hrs,  
a.voltsd_24hrs, a.rotatesd_24hrs, a.pressuresd_24hrs, a.vibrationsd_24hrs, 
a.error1count, a.error2count, a.error3count, a.error4count, a.error5count,
a.sincelastcomp1, a.sincelastcomp2, a.sincelastcomp3, a.sincelastcomp4, 
a.model, a.age, isnull(a.failure,'none') as failure 
into labeledfeat 
from
(select ff.*, l.failure
from finalfeat ff left join labeled l on ff.datetime=l.datetime and ff.machineID=l.machineID) a
order by machineID, datetime

select top 10 * from labeledfeat where machineID=1
order by machineID, datetime

select top 10 * from labeledfeat where failure ='comp4' and machineID=1
order by machineID, datetime

select distinct(failure), count(*) 
from labeledfeat
group by failure

select distinct(model), count(*) 
from labeledfeat
group by model

select top 10 * from labeledfeat where machineID=1 and failure='comp4'

select count(*) from labeledfeat

-- split at 2015-10-01 01:00:00, to train on the first 10 months and test on last 2 months
-- labelling window is 24 hours so records within 24 hours prior to split point are left out
drop table if exists trainingdata
drop table if exists testingdata

select * 
into trainingdata
from labeledfeat where datetime < '2015-09-30 01:00:00'
order by datetime

select * 
into testingdata
from labeledfeat where datetime > '2015-10-01 01:00:00'
order by datetime

select top 10 * from trainingdata where machineID = 100 order by datetime desc, machineID desc
select top 10 * from testingdata where machineID = 1 order by datetime asc, machineID asc

select count(*) from trainingdata
select count(*) from testingdata
