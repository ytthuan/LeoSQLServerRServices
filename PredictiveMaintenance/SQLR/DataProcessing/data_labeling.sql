SET ANSI_NULLS ON
GO

/****** Create the Stored Procedure for PM Template ******/

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS data_labeling
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [data_labeling] @dataset_type varchar(20),
                                 @connectionString varchar(300)
AS
BEGIN

  DECLARE @inquery NVARCHAR(max) = N'SELECT * FROM PM_Train';

  EXEC sp_execute_external_script @language = N'R',
                                  @script = N'								  

library("plyr")
####################################################################################################
## The data source to add labels: 
## 	PM_Train: Raw train dataset
##      PM_Test: Raw test dataset
####################################################################################################
dataset_type <- tolower(dataset_type)
source_table <- "PM_Train"
if (identical(dataset_type, "test")) {
  source_table <- "PM_Test"
}
####################################################################################################
## Add labels to raw data
## Three set of labels will be generated based on the models we use:
## 	Regression models: RUL column, it represents how many more cycles 
##			   an engine will last before it fails 
## Binary classification: Label1 column, it represents whether this engine going to fail 
##			  within number of cycles 
## Multi-class classification: Label2 column, it represents whether this engine going to 
##                             fail within the window [1, w0] cycles or to fail within the 
##                             window [w0+1, w1] cycles, or it will not fail within w1 cycles? 
####################################################################################################
data_label <- function(data) { 
  data <- as.data.frame(data)  
  max_cycle <- plyr::ddply(data, "id", plyr::summarise, max = max(cycle))
  if (!is.null(truth)) {
    max_cycle <- plyr::join(max_cycle, truth, by = "id")
    max_cycle$max <- max_cycle$max + max_cycle$RUL
    max_cycle$RUL <- NULL
  }
  data <- plyr::join(data, max_cycle, by = "id")
  # Label for regression
  data$RUL <- data$max - data$cycle
  # Label for binary/multi-class classification
  data$label1 <- ifelse(data$RUL <= 30, 1, 0)
  # Label for multi-class classification
  data$label2 <- ifelse(data$RUL <= 15, 2, data$label1)
  data$max <- NULL
  
  return(data)
}

####################################################################################################
## Add labels to the raw dataset and save it to SQL table
####################################################################################################
tablename <- paste("Labeled", dataset_type, "data", sep = "_")
labelDataSource = RxSqlServerData(table = tablename, 
                                  connectionString = connection_string)	  

inDataSource <- RxSqlServerData(table = source_table, 
                                connectionString = connection_string, 
                                rowsPerRead=30000)

truth_df = NULL
if (identical(dataset_type, "test")) {
  truth_columns <- c(RUL = "numeric")
  truth_table <- RxSqlServerData(table = "PM_Truth",
                                 connectionString = connection_string,
                                 colClasses = truth_columns, 
				 rowsPerRead=30000)
  truth_df <- rxImport(truth_table)
  #add index to the original truth table 
  truth_df$id <- 1:nrow(truth_df)
}   
 rxDataStep(inData = inDataSource, 
             outFile = labelDataSource,  
             overwrite = TRUE,
             transformObjects = list(truth = truth_df),
             transformFunc = data_label, 
             rowsPerRead=-1, 
             reportProgress = 3)'
, @input_data_1 = @inquery
, @params = N'@dataset_type varchar(20), @connection_string varchar(300)'
, @dataset_type = @dataset_type 
, @connection_string = @connectionString                     
END
;
GO

