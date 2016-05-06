SET ANSI_NULLS ON
GO

/****** Create the Stored Procedure for PM Template ******/

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS score_regression_rf 
GO

TRUNCATE TABLE RetailForecasting_models_rf
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [score_regression_rf] @connectionString varchar(300),
                                       @nTree int,
				       @maxDepth int
AS
BEGIN
  DECLARE @inquery NVARCHAR(max) = N'SELECT * from train'
  INSERT INTO RetailForecasting_models_rf
  EXEC sp_execute_external_script @language = N'R',
                                  @script = N'
sql_share_directory <- paste("c:\\AllShare\\", Sys.getenv("USERNAME"), sep = "")
dir.create(sql_share_directory, recursive = TRUE)
sql <- RxInSqlServer(connectionString = connection_string, 
                     shareDir = sql_share_directory)
local <- RxLocalSeq()

train <- InputDataSet
####################################################################################################
## Regression formula
####################################################################################################
train_vars <- rxGetVarNames(train)
train_vars <- train_vars[train_vars != "time"]
formula <- as.formula(paste("value~", paste(train_vars, collapse = "+")))
####################################################################################################
## Decision forest modeling
####################################################################################################
# TODO: There is a bug in colClasses for sql compute context
# As the work around, setting it as local
# should change it back to sql compute context after it is fixed in RTM
rxSetComputeContext(local)
forest_model <- rxDForest(formula = formula,
                               data = train,
                               nTree = nTree,
                               maxDepth = maxDepth,
                               seed = 0)

test_table <- RxSqlServerData(table = "test",
                              connectionString = connection_string)

prediction_df <- rxImport(test_table)
   							   
predictions <- rxPredict(modelObject = forest_model,
                         data = prediction_df,
                         predVarNames = "forecast.DecFore",
                         overwrite = TRUE)
prediction_df <- cbind(prediction_df, predictions)
prediction_df$forecast.DecFore <- exp(prediction_df$forecast.DecFore)
prediction_df$value <- NULL							   
rxSetComputeContext(local)	
prediction_table <- RxSqlServerData(table = "Score_Decision_Forest",
                                    connectionString = connection_string)
rxDataStep(inData = prediction_df,
           outFile = prediction_table,
           overwrite = TRUE)
		   
trained_model <- data.frame(model = as.raw(serialize(forest_model, connection = NULL)));'
, @input_data_1 = @inquery
, @output_data_1_name = N'trained_model'
, @params = N'@connection_string varchar(300), @nTree int, @maxDepth int'
, @connection_string = @connectionString  
, @nTree = @nTree
, @maxDepth = @maxDepth                     
END
GO
