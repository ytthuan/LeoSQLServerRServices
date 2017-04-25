USE ResumeMatching
GO

DROP PROCEDURE IF EXISTS score_for_matching_batch_2600_MML2;
GO

CREATE PROCEDURE score_for_matching_batch_2600_MML2(
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

	declare @inquery nvarchar(max) = N'select 1 as Label,PersonId,DocId,ProjectId';
	while (@i <= @topics)
	begin
		set @inquery += concat(N',RT', @i);
		set @i = @i + 1
	end
	while (@j <= @topics)
	begin
		set @inquery += concat(N',PT', @j);
		set @j = @j + 1
	end

	set @inquery += concat(N' 
	from [dbo].[Resumes] r, [dbo].[Projects] p 
	where ProjectId = ', @projectid, 
	N'and r.personId between ', @start+@baseid, N' and ', @end+@baseid,
	N'option(maxdop 5)')

	DECLARE @modelr varbinary(max) = (select model from [dbo].[ClassificationModelR] where [modelName]=@model_name);
	declare @instance_name nvarchar(100) = @@SERVERNAME
	declare @database_name nvarchar(128) = db_name() 

	INSERT INTO [dbo].[PredictionsR] (PersonId, DocId, ProjectId, Probability)
	EXEC sp_execute_external_script 
	@language = N'R',
	@script = N'
	# Define the connection string
	connStr <- paste("Driver=SQL Server;Server=", instance_name, ";Database=", database_name, ";Trusted_Connection=true;", sep="");
	# Set ComputeContext
	cc <- RxInSqlServer(connectionString = connStr, numTasks = 5);
	rxSetComputeContext(cc);
	# Parameter rowsPerRead played a significant role during prediction, 50K is the best configuration in this test
	featureDataSource = RxSqlServerData(sqlQuery = input_query, connectionString = connStr, stringsAsFactors = FALSE, rowsPerRead = 50000);

	library("MicrosoftML")

	topic_num <- 50
	mod <- unserialize(as.raw(model));
	rxSetComputeContext("local");
	predict_duration <- system.time(pred_scores <- rxPredict(mod,
		featureDataSource, 
		extraVarsToWrite=c("PersonId", "DocId", "ProjectId")
		))[3]
	pred_scores <- pred_scores[, c("PersonId", "DocId", "ProjectId", "Probability.1")]
	names(pred_scores) <- c("PersonId", "DocId", "ProjectId", "Probability")
	OutputDataSet <- subset(pred_scores, Probability >= threshold)
	',
	
	--@input_data_1 = @inquery,
	@output_data_1_name = N'OutputDataSet',
	@params = N'@model varbinary(max), @projectid bigint, @start int, @end int, @threshold float, @predict_duration float OUTPUT, @instance_name nvarchar(100), @database_name nvarchar(128), @input_query nvarchar(max)',
	@model = @modelr,
	@projectid = @projectid,
	@start = @start,
	@end = @end,
	@threshold = @threshold,
	@predict_duration = @predict_duration OUTPUT,
	@instance_name = @instance_name,
	@database_name = @database_name,
	@input_query = @inquery;


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