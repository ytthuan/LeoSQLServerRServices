SET ANSI_NULLS ON
GO

/****** Create the Stored Procedure for PM Template ******/

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS feature_engineering 
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [feature_engineering] @dataset_type varchar(20),
                                       @connectionString varchar(300)
AS
BEGIN
  DECLARE @inquery NVARCHAR(max) = N'SELECT 1 as Col'
  EXEC sp_execute_external_script @language = N'R',
                                  @script = N'
library("zoo")
library("plyr")
####################################################################################################
## The data source for feature engineering: 
## 	Labeled_train_data: Train dataset with labels added
##      Labeled_test_data: Test dataset with labels added
##	PM_Score: Raw dataset for scoring
####################################################################################################
dataset_type <- tolower(dataset_type)
source_table <- "Labeled_train_data"
if (identical(dataset_type, "test")) {
  source_table <- "Labeled_test_data"
}				  

if (identical(dataset_type, "score")) {
  source_table <- "PM_Score"
  
}								  
####################################################################################################
## Create features from the raw data
## Aggregated features by computing rolling means:
##   a1-a21: the moving average of sensor values in the most w recent cycles
##   sd1-sd21: the standard deviation of sensor values in the most w recent cycles
####################################################################################################
create_features <- function(data) {
  create_rolling_stats <- function(data) {
    data <- data[, sensor]
    rolling_mean <- zoo::rollapply(data = data,
                                    width = window,
                                    FUN = mean,
                                    align = "right",
                                    partial = 1)
    rolling_mean <- as.data.frame(rolling_mean)
    names(rolling_mean) <- gsub("s", "a", names(rolling_mean))
    rolling_sd <- zoo::rollapply(data = data,
                                  width = window,
                                  FUN = sd,
                                  align = "right",
                                  partial = 1)
    rolling_sd <- as.data.frame(rolling_sd)
    rolling_sd[is.na(rolling_sd)] <- 0
    names(rolling_sd) <- gsub("s", "sd", names(rolling_sd))
    rolling_stats <- cbind(rolling_mean, rolling_sd)
    return(rolling_stats)
  }

  data <- as.data.frame(data)
  window <- ifelse(window < nrow(data), window, nrow(data))  
  features <- plyr::ddply(data, "id", create_rolling_stats)
  features$id <- NULL
  data <- cbind(data, features)

  if (!identical(dataset_type, "train"))
  {
    max_cycle <- plyr::ddply(data, "id", plyr::summarise, cycle = max(cycle))
    data <- plyr::join(max_cycle, data, by = c("id", "cycle"))
  }

  return(data)
}

####################################################################################################
## Create features and save into SQL table
####################################################################################################
tablename <- paste(dataset_type, "Features", sep = "_")
featureDataSource = RxSqlServerData(table = tablename, 
                                    connectionString = connection_string)
  
inDataSource <- RxSqlServerData(table = source_table, 
                                connectionString = connection_string, 
                                rowsPerRead=30000)
window_size <- 5
vars <- names(rxGetVarInfo(data = inDataSource))
sensor_vars <- vars[grep("s[[:digit:]]", vars)]
  
rxDataStep(inData = inDataSource, 
            outFile = featureDataSource,  
            overwrite = TRUE,
            transformObjects = list(window = window_size,
                                    sensor = sensor_vars,
                                    dataset_type = dataset_type),
            transformFunc = create_features,
            rowsPerRead=-1, 
            reportProgress = 3)

  ####################################################################################################
  ## Data normalization
  ####################################################################################################
  trainFeaturesTable <- paste("train", "Features", sep = "_")
  trainFeatureDataSource = RxSqlServerData(table = trainFeaturesTable, 
                                          connectionString = connection_string)
  
  train_summary <- rxSummary(formula = ~ ., 
                              data = trainFeatureDataSource, 
                              summaryStats = c("min", "max"))
  train_summary <- train_summary$sDataFrame
  train_summary <- subset(train_summary, !Name %in% c("id", "RUL", "label1", "label2"))
  train_vars <- train_summary$Name
  train_vars_min <- train_summary$Min
  train_vars_max <- train_summary$Max
  
  normalize_data <- function(data) {
    data <- as.data.frame(data)
    data_to_keep <- data[, c("id", "cycle")]
    data$id <- NULL
    temp <- data[, vars]
	
	col_names <- c("id", "cycle_orig", "cycle","setting1","setting2",
                   "s2","s3","s4","s6","s7","s8","s9",
                   "s11","s12","s13","s14","s15",
                   "s17","s20","s21","a2","a3",
                   "a4","a6","a7","a8","a9",
                   "a11","a12","a13","a14","a15",
                   "a17","a20","a21","sd2","sd3",
                   "sd4","sd6","sd7","sd8","sd9",
                   "sd11","sd12","sd13","sd14","sd15",
                   "sd17","sd20","sd21","RUL","label1","label2")
    
    if(!"RUL" %in% colnames(data)) {
      col_names <- col_names[1:(length(col_names) - 3)]
    }
  
    normalize <- function(x, min, max) {
      z <- (x - min) / (max - min)
      return(z)
    }
  
    temp <- mapply(normalize, temp, vars_min, vars_max)
    ncols <- length(vars_min)
    nrows <- length(unlist(temp))/ncols
    temp_df <- data.frame(matrix(unlist(temp), nrow=nrows, byrow=F))
    for (i in 1:ncols){
      if (vars_max[i] == vars_min[i]){
        temp_df[,i] <- NA
      }
    }
    data <- data[, which(!names(data) %in% vars)]
    data <- cbind(data_to_keep, temp_df, data)
    data <- data[, apply(!is.na(data), 2, all)]

    colnames(data) <- col_names
    return(data)
  }
  
  ####################################################################################################
  ## Save the normalized dataset into SQL tables
  ####################################################################################################
  normedFeatureDataSource = RxSqlServerData(table = paste(dataset_type, "Features_Normalized", sep = "_"), 
  					    connectionString = connection_string)

  rxDataStep(inData = featureDataSource,
              outFile = normedFeatureDataSource,
              transformObjects = list(vars = train_vars,
                                      vars_min = train_vars_min,
                                      vars_max = train_vars_max),
              transformFunc = normalize_data,
              overwrite = TRUE)'
, @input_data_1 = @inquery
, @params = N'@dataset_type varchar(20), @connection_string varchar(300)'
, @dataset_type = @dataset_type    
, @connection_string = @connectionString                   
END

;
GO

