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