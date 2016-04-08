IF OBJECT_ID('dbo.usp_delete_job', 'P') IS NOT NULL
  DROP PROCEDURE [dbo].[usp_delete_job]
GO

IF OBJECT_ID('dbo.usp_create_job', 'P') IS NOT NULL
  DROP PROCEDURE [dbo].[usp_create_job]
GO


create procedure usp_delete_job (@dbname NVARCHAR(64))
as
BEGIN
	DECLARE @jobId binary(16)
	DECLARE @jobName NVARCHAR(64)
	
	-- delete demand data simulator
	set @jobName = concat(@dbname,'_',N'Energy_Demand_data_simulator')
		
	SELECT @jobId = job_id FROM msdb.dbo.sysjobs WHERE (name = @jobName)
	IF (@jobId IS NOT NULL)
	BEGIN
		EXEC msdb.dbo.sp_delete_job @jobId
	END;

	-- delete temperature data simulator
	set @jobid=NULL
	set @jobName = concat(@dbname,'_',N'Energy_Temperature_data_simulator')	
	SELECT @jobId = job_id FROM msdb.dbo.sysjobs WHERE (name = @jobName)
	IF (@jobId IS NOT NULL)
	BEGIN
		EXEC msdb.dbo.sp_delete_job @jobId
	END;
	
	--delete jobs for each region
	DECLARE @MyCursor CURSOR;
	DECLARE @region varchar(64);
	DECLARE @sp NVARCHAR(200)	
	BEGIN
		SET @MyCursor = CURSOR FOR
		select distinct region from demandseed;

		OPEN @MyCursor 
		FETCH NEXT FROM @MyCursor INTO @region

		WHILE @@FETCH_STATUS = 0
		BEGIN
			set @jobid=NULL
			set @jobName = concat(upper(@dbname),'_',N'prediction_job','_',@region)
			SELECT @jobId = job_id FROM msdb.dbo.sysjobs WHERE (name = @jobName)
			IF (@jobId IS NOT NULL)
			BEGIN
				EXEC msdb.dbo.sp_delete_job @jobId
			END;	
			
			FETCH NEXT FROM @MyCursor INTO @region 
		END; 

		CLOSE @MyCursor ;
		DEALLOCATE @MyCursor;
	END;	
END;
GO

create procedure usp_create_job (@servername varchar(100), @dbname VARCHAR(64), @username varchar(64), @pswd varchar(64), @WindowsORSQLAuthenticationFlag varchar(5))
as
Begin
	BEGIN TRANSACTION
	DECLARE @ReturnCode INT
	SELECT @ReturnCode = 0
	DECLARE @jobName NVARCHAR(64)
	DECLARE @jobId BINARY(16)
	Set @jobid = NULL
	set @jobName = concat(upper(@dbname),'_',N'Energy_Demand_data_simulator')
	EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=@jobName, 
			@description=N'Simulator for generating energy demand data in every 15 minutes', 
			@job_id = @jobId OUTPUT
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

	EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'generatorData', 
			@step_id=1, 
			@subsystem=N'TSQL', 
			@command=N'exec usp_Data_Simulator_Demand;', 
			@database_name=@dbName ,
			@retry_attempts = 5,
			@retry_interval = 5;
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'RunEvery15Minutes', 
			@enabled=1, 
			@freq_type=4, 
			@freq_interval=1, 
			@freq_subday_type=4, 
			@freq_subday_interval=15, 
			@freq_relative_interval=0, 
			@freq_recurrence_factor=0, 
			@active_start_date=20160222, 
			@active_end_date=99991231, 
			@active_start_time=0, 
			@active_end_time=235959
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

	set @jobid=NULL
	set @jobName = concat(upper(@dbname),'_',N'Energy_Temperature_data_simulator')
	EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=@jobName, 
			@description=N'Simulator for generating energy demand data in every 15 minutes', 
			@job_id = @jobId OUTPUT
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

	EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'generatorData', 
			@step_id=1, 
			@subsystem=N'TSQL', 
			@command=N'exec usp_Data_Simulator_Temperature;', 
			@database_name=@dbname ,
			@retry_attempts = 5,
			@retry_interval = 5;
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'RunEvery1Hour', 
			@enabled=1, 
			@freq_type=4, 
			@freq_interval=1, 
			@freq_subday_type=8, 
			@freq_subday_interval=1, 
			@freq_relative_interval=0, 
			@freq_recurrence_factor=0, 
			@active_start_date=20160222, 
			@active_end_date=99991231, 
			@active_start_time=0, 
			@active_end_time=235959
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

	
	--create jobs for each region
	DECLARE @MyCursor CURSOR;
	DECLARE @region varchar(64);
	DECLARE @sp NVARCHAR(200)	
	BEGIN
		SET @MyCursor = CURSOR FOR
		select distinct region from RegionLookup;

		OPEN @MyCursor 
		FETCH NEXT FROM @MyCursor INTO @region

		WHILE @@FETCH_STATUS = 0
		BEGIN
			Set @jobid = NULL
			set @jobName = concat(upper(@dbname),'_',N'prediction_job','_',@region)
			SET @sp = N'exec [dbo].[usp_energyDemandForecastMain] ''' + @region  + ''', ''' + @servername  + ''', ''' + @dbname  + ''', ''' + @username  + ''', ''' +@pswd  + ''','''+ @WindowsORSQLAuthenticationFlag + '''';
			print @sp
			EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=@jobName, 
					@description=N'Predict energy demand data in every 15 minutes', 
					@job_id = @jobId OUTPUT
			IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

			EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'prediction', 
					@step_id=1, 
					@subsystem=N'TSQL', 
					@command=@sp, 
					@database_name=@dbName ,
					@retry_attempts = 5,
					@retry_interval = 5;
			IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
			EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
			IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
			EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'RunEvery15Minutes', 
					@enabled=1, 
					@freq_type=4, 
					@freq_interval=1, 
					@freq_subday_type=4, 
					@freq_subday_interval=15, 
					@freq_relative_interval=0, 
					@freq_recurrence_factor=0, 
					@active_start_date=20160222, 
					@active_end_date=99991231, 
					@active_start_time=0, 
					@active_end_time=235959
			IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
			EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
			IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback		
			
			FETCH NEXT FROM @MyCursor INTO @region 
		END; 

		CLOSE @MyCursor ;
		DEALLOCATE @MyCursor;
	END;

	COMMIT TRANSACTION
	GOTO EndSave
	QuitWithRollback:
		IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
	EndSave:
END;
GO