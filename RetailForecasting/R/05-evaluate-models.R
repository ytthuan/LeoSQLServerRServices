####################################################################################################
## Compute context
####################################################################################################
connection_string <- "Driver=SQL Server;
                      Server=[SQL Server Name];
                      Database=[Database Name];
                      UID=[User ID];
                      PWD=[User Password]"
sql_share_directory <- paste("c:\\AllShare\\", Sys.getenv("USERNAME"), sep = "")
dir.create(sql_share_directory, recursive = TRUE)
sql <- RxInSqlServer(connectionString = connection_string, 
                     shareDir = sql_share_directory)
local <- RxLocalSeq()
####################################################################################################
## Join both forecast tables
####################################################################################################
join_forecast_tables <- function(in_table1, in_table2, out_table) {
  
  library(plyr)
  data1 <- rxImport(in_table1)
  data2 <- rxImport(in_table2)
  
  data <- join(data1, data2, by = c("ID1", "ID2", "time"), type = "inner")
  
  data_file_path <- file.path(tempdir(), "data.csv")
  write.csv(x = data, 
            file = data_file_path,
            row.names = FALSE)
  data_text <- RxTextData(file = data_file_path)
  rxDataStep(inData = data_text,
             outFile = out_table,
             overwrite = TRUE)
}
rxSetComputeContext(sql)
all_forecasts_table <- RxSqlServerData(table = "all_forecasts",
                                       connectionString = connection_string)
regression_forecasts_table <- RxSqlServerData(table = "regression_forecasts",
                                              connectionString = connection_string)
forecasting_results_table <- RxSqlServerData(table = "forecasting_results",
                                             connectionString = connection_string)
rxExec(join_forecast_tables, 
       in_table1 = all_forecasts_table,
       in_table2 = regression_forecasts_table,
       out_table = forecasting_results_table)
####################################################################################################
## Join test results to cleaned forecasting table
####################################################################################################
join_tables <- function(in_table1, in_table2, out_table) {
  
  library(plyr)
  data1 <- rxImport(in_table1)
  data2 <- rxImport(in_table2)
  
  data <- join(data1, data2, by = c("ID1", "ID2", "time"), type = "left")
  
  data_file_path <- file.path(tempdir(), "data.csv")
  write.csv(x = data, 
            file = data_file_path,
            row.names = FALSE)
  data_text <- RxTextData(file = data_file_path)
  rxDataStep(inData = data_text,
             outFile = out_table,
             overwrite = TRUE)
}
rxSetComputeContext(sql)
forecasting_table <- RxSqlServerData(table = "forecasting",
                                     connectionString = connection_string)
forecasting_results_table <- RxSqlServerData(table = "forecasting_results",
                                             connectionString = connection_string)
final_forecasts_table <- RxSqlServerData(table = "final_forecasts",
                                         connectionString = connection_string)
rxExec(join_tables, 
       in_table1 = forecasting_table,
       in_table2 = forecasting_results_table,
       out_table = final_forecasts_table)
####################################################################################################
## Modeling parameters
####################################################################################################
test.length <- 52
seasonality <- 52
observation.freq <- "week"
timeformat <- "%m/%d/%Y"
####################################################################################################
## Metrics summary
####################################################################################################
get_metrics_summary <- function(in_table, out_table) {
  
  library(forecast)
  library(plyr)
  library(car)
  
  data <- rxImport(in_table)
  # Date format clean-up
  data$time <- as.POSIXct(as.numeric(as.POSIXct(data$time, 
                                                format = "%Y-%m-%d",
                                                tz = "UTC", 
                                                origin = "1970-01-01"),
                                     tz = "UTC"), 
                          tz = "UTC", 
                          origin = "1970-01-01")
  
  print("Note that MASE is less than one if it arises from a better forecast than 
        the average naive forecast.")
  
  # Helper function
  extract.col <- function(pattern, df){
    col.indices <- grep(pattern, colnames(df), ignore.case = TRUE)
    return(df[, col.indices, drop = FALSE])
  }
  
  # Metric Functions
  mase <- function(true, forecast){
    error = 0;
    if (length(true) != length(forecast)) {
      return (NA);
    } else if (length(true) == 0 || length(forecast) == 0) {
      return (NA);
    }
    else {
      denom = (sum(abs(true[2:length(true)] - true[1:(length(true) - 1)])))/(length(true) - 1)
      error = sum((abs(true-forecast)) / denom)/length(true);
    }
    return (error);
  }
  
  get.metrics <- function(true, forecast){
    forecast.metrics <- as.data.frame(accuracy(forecast, true))
    return(data.frame(forecast.metrics[, colnames(forecast.metrics) !="ME"], MASE = mase(true, forecast)))
  }
  
  get.metrics.single.id <- function(data){
    # Extract forecast values
    data.forecast <- extract.col("forecast\\.[a_z]*", df = data)
    
    # Split true data and forecast values
    is.test <- !is.na(data.forecast[,1])
    
    test.true <- data$value[is.test]
    test.forecast <- data.forecast[is.test, ]
    test.time <- data$time[is.test]
    
    test.nonna <- complete.cases(test.true)
    test.true <- test.true[test.nonna]
    test.forecast <- test.forecast[test.nonna,]
    #test.time <- test.time[test.nonna]
    
    # Calculate error metrics
    output <- t(sapply(test.forecast, get.metrics, true = test.true))
    
    methods <- sub("[a-z]+\\.", "", rownames(output), ignore.case = TRUE)
    output <- apply(output, c(1,2),as.numeric)
    output <- data.frame(test.length.nonna = sum(test.nonna), Method = methods, output)
    rownames(output) <- NULL
    return(output)
  }
  
  metrics.all.ids <- ddply(data, c("ID1", "ID2"), get.metrics.single.id)
  
  get.mean.metric.summary <- function(mean.metric, N){
    return(weighted.mean(mean.metric, N))
  }
  
  get.rmse.summary <- function(rmse.metric, N){
    return(c("RMSE" = sqrt(weighted.mean(rmse.metric^2, N))))
  }
  
  get.metrics.summary <- function(metrics.all.ids){
    summary.mean <- apply(extract.col("^M[A-Z]+E", metrics.all.ids), MARGIN = 2, 
                          FUN = get.mean.metric.summary, N = metrics.all.ids$test.length.nonna)
    
    summary.rmse <- get.rmse.summary(metrics.all.ids$RMSE, metrics.all.ids$test.length.nonna)
    return(c(summary.mean, summary.rmse))
  }
  
  metrics.summary <- ddply(metrics.all.ids, c("Method"), get.metrics.summary)

  rxDataStep(inData = metrics.summary,
             outFile = out_table,
             overwrite = TRUE)
  
  return(metrics.all.ids)
}
rxSetComputeContext(sql)
final_forecasts_table <- RxSqlServerData(table = "final_forecasts",
                                         connectionString = connection_string)
metrics_summary_table <- RxSqlServerData(table = "metrics_summary",
                                         connectionString = connection_string)
metrics.all.ids <- rxExec(get_metrics_summary, 
                          in_table = final_forecasts_table,
                          out_table = metrics_summary_table)
metrics.all.ids <- metrics.all.ids[[1]]

metric.names <- grep("^M[A-Z]+E|RMSE", colnames(metrics.all.ids), ignore.case = TRUE, value = TRUE)

plot.metric <- function(metric.name){
  png(filename = paste(metric.name,".png", sep = ""), width = 2040, height = 720)
  par(oma = c(1, 1.2, 3, 1), mar = c(6, 6, 6, 2), mfrow = c(1, 2), cex.lab=1.1, cex.axis=1.1, cex.main=1.3, cex.sub=1.3)
  command <- paste("boxplot(", metric.name, "~Method, data = metrics.all.ids, id.method = \"y\", id.n = Inf, main = \"", metric.name, "\")", sep = "")
  eval(parse(text = command))
  mtext("The (ID1, ID2) of each outlier is provided beside the point", side = 3, line = 0.5, cex = 1.3)
  command <- paste("boxplot(", metric.name, "~Method, data = metrics.all.ids,  id.method = \"none\", id.n = 0, main = \"", metric.name, " without outliers\", outline = FALSE)", sep = "")
  eval(parse(text = command))
  mtext("The outliers are removed to better present the scale of boxes", side = 3, line = 0.5, cex = 1.3)
  graph.title = paste("Model Comparison under Metric", metric.name)
  title(graph.title, outer = TRUE)
  box("inner", lty = 3)
  dev.off()
}

g <- lapply(metric.names, FUN = plot.metric)
####################################################################################################
## Extract single time series
####################################################################################################
rxSetComputeContext(sql)
final_forecasts_table <- RxSqlServerData(table = "final_forecasts",
                                         connectionString = connection_string)
data <- rxDataStep(inData = final_forecasts_table,
                   rowSelection = (ID1 == 12) & (ID2 == 1))
# Date format clean-up
data$time <- as.POSIXct(as.numeric(as.POSIXct(data$time, 
                                              format = "%Y-%m-%d",
                                              tz = "UTC", 
                                              origin = "1970-01-01"),
                                   tz = "UTC"), 
                        tz = "UTC", 
                        origin = "1970-01-01")
# Helper function
extract.col <- function(pattern, df = data){
  col.indices <- grep(pattern, colnames(df), ignore.case = TRUE)
  return(df[, col.indices, drop = FALSE])
}

# Metric Functions
library(forecast)

mase <- function(true, forecast){
  error = 0;
  if (length(true) != length(forecast)) {
    return (NA);
  } else if (length(true) == 0 || length(forecast) == 0) {
    return (NA);
  }
  else {
    denom = (sum(abs(true[2:length(true)] - true[1:(length(true) - 1)])))/(length(true) - 1)
    error = sum((abs(true-forecast)) / denom)/length(true);
  }
  return (error);
}

metrics <- function(true, forecast){
  forecast.metrics <- as.data.frame(accuracy(forecast, true))
  return(data.frame(forecast.metrics[, colnames(forecast.metrics) !="ME"], MASE = mase(true, forecast)))
}

# Extract forecast values
data.forecast <- extract.col("forecast\\.[a_z]*")

# Split true data and forecast values
is.test <- !is.na(data.forecast[,1])

test.true <- data$value[is.test]
test.forecast <- data.forecast[is.test, ]
test.time <- data$time[is.test]

test.nonna <- complete.cases(test.true)
test.true <- test.true[test.nonna]
test.forecast <- test.forecast[test.nonna,]
test.time <- test.time[test.nonna]

# Calculate error metrics
output <- t(sapply(test.forecast, metrics, true = test.true))

methods <- sub("[a-z]+\\.", "", rownames(output), ignore.case = TRUE)
output <- apply(output, c(1,2),as.numeric)
output <- data.frame(Method = methods, output)
rownames(output) <- NULL

# Plot
time <- data$time
true <- as.numeric(data$value)
value.data <- unlist(data[, !(names(data) %in% c("time", "ID1", "ID2"))])
min.data <- min(value.data, na.rm = TRUE)
max.data <- max(value.data, na.rm = TRUE)

graph.ts <- function(method){
  forecast.value <- data[, paste("forecast.", method, sep = "")]
  
  have.ci <- tryCatch(
    {
      lo95 <- data[, paste("lo95.", method, sep = "")]
      hi95 <- data[, paste("hi95.", method, sep = "")]
      have.ci <- TRUE
    },
    error = function(e){
      have.ci <- FALSE
    }
  )
  graph.title <- paste("Forecast by", method)
  
  plot(time, true, type="l",col="blue",xlab="Time",ylab="Data",lwd=2, bty="l", main = "Time Series Plot", ylim = c(min(0,min.data*0.95), max.data * 1.05))
  grid(col = "gray")
  lines(time, forecast.value, col = "red", lwd = 2)
  
  # plot confidence interval
  if (have.ci){
    ci.color <- adjustcolor("gray",alpha.f=0.5)
    lines(time, lo95, col = ci.color, lwd = 2)
    lines(time, hi95, col = ci.color, lwd = 2)
    polygon(c(time, rev(time)), c(hi95, rev(lo95)), col = ci.color, border = NA)
    
    # add legend
    legend("top",legend = c("True Data", "Forecast", "95% Confidence Interval"),
           bty=c("n","n"), lty=c(1, 1, 1), lwd = c(2, 2, 10), horiz = TRUE,
           col=c("blue","red", ci.color), cex = 1.5)
  }
  else{
    # add legend
    legend("top",legend = c("True Data", "Forecast"),
           bty=c("n","n"), lty=c(1, 1), lwd = c(2, 2), horiz = TRUE,
           col=c("blue","red"), cex = 1.5)
    return(NULL)
  }
}


error.forecast <- apply(test.forecast, 2, "-", test.true)
colnames(error.forecast) <- sub("forecast", "error", colnames(error.forecast))
max.abs.error <- max(abs(error.forecast), na.rm = TRUE)

graph.error <- function(method){
  error <- error.forecast[, paste("error.", method, sep = "")]
  error.mean <- mean(error)
  error.sd <- sd(error)
  
  # error vs time
  plot(test.time, error, type = "h", bty = "l", xlab = "Time", ylab = "Prediction Error", 
       main = "Prediction Error VS Time",  ylim = c(-max.abs.error, max.abs.error))
  abline(0,0)
  abline(1.96*error.sd, 0, lty = 2, col = "blue")
  abline(-1.96*error.sd, 0, lty = 2, col = "blue")
  
  # error histogram
  error.hist <- hist(error, density = 20, bty = "l", xlab = "Prediction Error", 
                     main = "Histogram of Prediction Error", xlim = c(-max.abs.error*1.1, max.abs.error*1.1))
  x <- (-max.abs.error*1.1) : (max.abs.error*1.1)
  multiplier <- (error.hist$counts / error.hist$density)[1]
  lines(x, dnorm(x, 0, error.sd)*multiplier, col = "red")
  
  # ACF and PACF
  acf(error, main = "", bty = "l", ylim = c(-1, 1))
  title("Auto-Correlation Function of Errors", line = 1)
  pacf(error, main = "", bty = "l", ylim = c(-1, 1), xlim = c(1, 20))
  title("Partial Auto-Correlation Function of Errors", line = 1)
  
  return(NULL)
}

ID1 <- data$ID1[1]
ID2 <- data$ID2[1]

graph <- function(method){
  png(filename = paste(method,".png", sep = ""), width = 1080, height = 1620)
  layout(matrix(c(1,1,2,3,4,5), 3, 2, byrow = TRUE), heights = c(1.1, 1, 1))
  par(oma = c(1, 1.2, 3, 1), mar = c(3.5, 3.5, 2, 1), mgp = c(1.8, 0.5, 0), 
      cex.lab=1.4, cex.axis=1.3, cex.main=2, cex.sub=1.5)
  graph.ts(method)
  graph.error(method)
  graph.title <- paste("Model Goodness of", method, "for ID1 =", ID1, "and ID2 =", ID2)
  title(graph.title, outer = TRUE)
  box("inner", lty = 3)
  dev.off()
}

g <- lapply(methods, FUN = graph)
####################################################################################################
## Cleanup
####################################################################################################
rm(list = ls())