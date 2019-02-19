declare @pid bigint = 1000001

select project_id, datediff_big(ms, min(start_time), max(end_time))/1000.0 as duration from [dbo].[scoring_stats]
where project_id = @pid
group by project_id

select * from [dbo].[scoring_stats] where project_id = @pid