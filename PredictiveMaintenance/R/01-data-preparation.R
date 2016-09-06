####################################################################################################
## This R script will do the following:
## 1. Data uploading into SQL tables;
## 2. Data labeling for raw train and test data;
## 3. Feature engineering for train and test data;
## 4. Feature normalization for train and test data
## Input : The csv files of train, test and truth data
## Output: train-Features and test-Features SQL tables for further model training
####################################################################################################
file_path <- "../Data"
####################################################################################################
## Compute context
####################################################################################################
connection_string <- "Driver=SQL Server;
                      Server=[SQL server name];
                      Database=[Database Name];
                      UID=[UserName];
                      PWD=[Password]"
sql_share_directory <- paste("c:\\AllShare\\", Sys.getenv("USERNAME"), sep = "")
dir.create(sql_share_directory, recursive = TRUE, showWarnings = FALSE)
sql <- RxInSqlServer(connectionString = connection_string, 
                     shareDir = sql_share_directory)
local <- RxLocalSeq()
####################################################################################################
## Train metadata
####################################################################################################
train_columns <- c(id = "numeric",
                   cycle = "numeric",
                   setting1 = "numeric",
                   setting2 = "numeric",
                   setting3 = "numeric",
                   s1 = "numeric",
                   s2 = "numeric",
                   s3 = "numeric",
                   s4 = "numeric",
                   s5 = "numeric",
                   s6 = "numeric",
                   s7 = "numeric",
                   s8 = "numeric",
                   s9 = "numeric",
                   s10 = "numeric",
                   s11 = "numeric",
                   s12 = "numeric",
                   s13 = "numeric",
                   s14 = "numeric",
                   s15 = "numeric",
                   s16 = "numeric",
                   s17 = "numeric",
                   s18 = "numeric",
                   s19 = "numeric",
                   s20 = "numeric",
                   s21 = "numeric")
####################################################################################################
## Load train data into SQL table
####################################################################################################
train_file <- "PM_Train.csv"
train_file_path <- file.path(file_path, train_file)

train_data_text <- RxTextData(file = train_file_path,
                              colClasses = train_columns)
train_table_name <- strsplit(basename(train_file), "\\.")[[1]][1]
train_data_table <- RxSqlServerData(table = train_table_name,
                                    connectionString = connection_string,
                                    colClasses = train_columns)
rxDataStep(inData = train_data_text,
           outFile = train_data_table,
           overwrite = TRUE)

####################################################################################################
### Data exploration examples
####################################################################################################

rxSummary( ~ ., train_data_table)
rxHistogram(~s11,train_data_table)
rxHistogram( ~ s11 | F(id), type = "p", data = train_data_table)
rxLinePlot(s11~cycle|id,train_data_table)

####################################################################################################
## Load test data into SQL table
####################################################################################################
test_file <- "PM_Test.csv"
test_file_path <- file.path(file_path, test_file)

test_data_text <- RxTextData(file = test_file_path,
                              colClasses = train_columns)
test_table_name <- strsplit(basename(test_file), "\\.")[[1]][1]
test_data_table <- RxSqlServerData(table = test_table_name,
                                    connectionString = connection_string,
                                    colClasses = train_columns)
rxDataStep(inData = test_data_text,
           outFile = test_data_table,
           overwrite = TRUE)

####################################################################################################
## Load truth data into SQL table
####################################################################################################
truth_file <- "PM_Truth.csv"
truth_columns <- c(RUL = "numeric")
truth_file_path <- file.path(file_path, truth_file)

truth_data_text <- RxTextData(file = truth_file_path,
                             colClasses = truth_columns)
truth_table_name <- strsplit(basename(truth_file), "\\.")[[1]][1]
truth_data_table <- RxSqlServerData(table = truth_table_name,
                                   connectionString = connection_string,
                                   colClasses = truth_columns)
rxDataStep(inData = truth_data_text,
           outFile = truth_data_table,
           overwrite = TRUE)

####################################################################################################
## Data labeling
## Three set of labels will be generated based on the models we use:
## 	Regression models: RUL column, it represents how many more cycles 
##			   an engine will last before it fails 
## Binary classification: Label1 column, it represents whether this engine going to fail 
##			  within number of cycles 
## Multi-class classification: Label2 column, it represents whether this engine going to 
##                             fail within the window [1, w0] cycles or to fail within the 
##                             window [w0+1, w1] cycles, or it will not fail within w1 cycles? 
####################################################################################################
library(plyr)
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
## Add data labels for train data
####################################################################################################
tagged_table_name <- "train_Labels"
truth_df <- NULL 
tagged_table_train = RxSqlServerData(table = tagged_table_name, 
                                             colClasses = train_columns,
                                             connectionString = connection_string)
inDataSource <- RxSqlServerData(table = train_table_name, 
                                connectionString = connection_string, 
                                colClasses = train_columns,
                                rowsPerRead=30000)
rxDataStep(inData = inDataSource, 
           outFile = tagged_table_train,  
           overwrite = TRUE,
           transformObjects = list(truth = truth_df),
           transformFunc = data_label, 
           rowsPerRead=-1, 
           reportProgress = 3)

####################################################################################################
## Add data labels for test data
####################################################################################################
truth_df <- rxImport(truth_data_table)
#add index to the original truth table 
truth_df$id <- 1:nrow(truth_df)
tagged_table_name <- "test_Labels"
tagged_table_test = RxSqlServerData(table = tagged_table_name, 
                                           colClasses = train_columns,
                                           connectionString = connection_string)
inDataSource <- RxSqlServerData(table = test_table_name, 
                                connectionString = connection_string, 
                                colClasses = train_columns,
                                rowsPerRead=30000)
rxDataStep(inData = inDataSource, 
           outFile = tagged_table_test,  
           overwrite = TRUE,
           transformObjects = list(truth = truth_df),
           transformFunc = data_label, 
           rowsPerRead=-1, 
           reportProgress = 3)
####################################################################################################
## Create features from the raw data by computing the rolling means
## Only the last cycle of each test engine is selected for prediction
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
  
  if (!identical(data_type, "train"))
  {
    max_cycle <- plyr::ddply(data, "id", plyr::summarise, cycle = max(cycle))
    data <- plyr::join(max_cycle, data, by = c("id", "cycle"))
  }
  
  return(data)
}

window_size <- 5
train_vars <- names(rxGetVarInfo(tagged_table_train))
sensor_vars <- train_vars[grep("s[[:digit:]]", train_vars)]
rxSetComputeContext(sql)

####################################################################################################
## Create features for train dataset and save into SQL table
####################################################################################################
train_table <- RxSqlServerData(table = "train_Features",
                               connectionString = connection_string,
                               colClasses = train_columns)
                               
rxSetComputeContext(local)

rxDataStep(inData = tagged_table_train, 
           outFile = train_table,  
           overwrite = TRUE,
           transformObjects = list(window = window_size,
                                   sensor = sensor_vars,
                                   data_type = "train"),
           transformFunc = create_features,
           rowsPerRead=-1, 
           reportProgress = 3)

####################################################################################################
## Create features for test dataset and save into SQL table
####################################################################################################
test_table <- RxSqlServerData(table = "test_Features",
                              connectionString = connection_string,
                              colClasses = train_columns)

rxDataStep(inData = tagged_table_test, 
           outFile = test_table,  
           overwrite = TRUE,
           transformObjects = list(window = window_size,
                                   sensor = sensor_vars,
                                   data_type = "test"),
           transformFunc = create_features,
           rowsPerRead=-1, 
           reportProgress = 3)
####################################################################################################
## Feature normalization with min-max
####################################################################################################
train_summary <- rxSummary(formula = ~ ., 
                           data = train_table, 
                           summaryStats = c("min", "max"))
train_summary <- train_summary$sDataFrame
train_summary <- subset(train_summary, !Name %in% c("id", "RUL", "label1", "label2"))
train_vars <- train_summary$Name
train_vars_min <- train_summary$Min
train_vars_max <- train_summary$Max

normalize_data <- function(data) {
  data <- as.data.frame(data)
  data_to_keep <- data[, c("id", "cycle")]
  names(data_to_keep) <- c("id", "cycle_orig")
  data$id <- NULL
  temp <- data[, vars]
  normalize <- function(x, min, max) {
    z <- (x - min) / (max - min)
    return(z)
  }
  temp <- mapply(normalize, temp, vars_min, vars_max)
  temp[is.nan(temp)] <- NA
  data <- data[, which(!names(data) %in% vars)]
  data <- cbind(data_to_keep, temp, data)
  data <- data[, apply(!is.na(data), 2, all)]
  return(data)
}

####################################################################################################
## Train feature normalization
####################################################################################################
rxDataStep(inData = train_table,
           outFile = train_table,
           transformObjects = list(vars = train_vars,
                                   vars_min = train_vars_min,
                                   vars_max = train_vars_max),
           transformFunc = normalize_data,
           overwrite = TRUE)

####################################################################################################
## Test feature normalization 
####################################################################################################
rxDataStep(inData = test_table,
           outFile = test_table,
           transformObjects = list(vars = train_vars,
                                   vars_min = train_vars_min,
                                   vars_max = train_vars_max),
           transformFunc = normalize_data,
           overwrite = TRUE)

####################################################################################################
## Cleanup
####################################################################################################
rm(list = ls())
