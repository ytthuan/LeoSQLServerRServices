USE ResumeMatching
GO 

DROP PROCEDURE IF EXISTS train_model_for_matching_2600_MML2;
GO

CREATE PROCEDURE train_model_for_matching_2600_MML2 (@model_name varchar(100))
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

	library("MicrosoftML")

	topic_num <- 50

	# function used to generate the final 2600 features
	xform <- function(dataList)
	{
	  topics <- 50
  
	  fun_pt <- function(pt_idx, rt_idx, dataList) {
		target_name <- paste("C", (rt_idx-1)*topics+pt_idx, sep="")
		dataList[[target_name]] <<- dataList[[paste("RT", rt_idx, sep="")]] * dataList[[paste("PT", pt_idx, sep="")]]
	  }
  
	  fun_rt <- function(rt_idx, dataList) {
		sapply(c(1:50), fun_pt, rt_idx=rt_idx, dataList=dataList)
	  }
  
	  sapply(c(1:50), fun_rt, dataList=dataList)
	  # Return
	  dataList
	}

	
	feature_names <- c(setdiff(names(InputDataSet), c("Label")), paste("C", c(1:2500), sep=""))
	myformula <- as.formula(paste("Label", paste(feature_names, collapse = " + "), sep = " ~ "))
	fastTrees <- rxFastTrees(formula=myformula, 
				data=InputDataSet,
				transformFunc = xform,
				transformVars = c(paste("RT", c(1:50), sep=""), paste("PT", c(1:50), sep ="")),
				numTrees=100,
				reportProgress=3,
				verbose=4);
	print(fastTrees)

	trained_model <- as.raw(serialize(fastTrees, NULL));
	',
	@input_data_1 = @inquery,
	@params  = N'@trained_model varbinary(max) OUTPUT',
	@trained_model = @trained_model OUTPUT;

	INSERT INTO [dbo].[ClassificationModelR] values(@model_name, @trained_model);
END;
GO