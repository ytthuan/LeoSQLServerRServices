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