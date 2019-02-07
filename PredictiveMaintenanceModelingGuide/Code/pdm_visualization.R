####################################################################################################
## This R script will do the following:
## 1) Visualize the data - combination of rxHistogram and local ggplots
####################################################################################################
##Load settings - user to add in their credentials
####################################################################################################
connection_string <- "Driver=SQL Server;
Server=....eastus2.cloudapp.azure.com,1433;
Database=...;
UID=...;
PWD=..."
sql_share_directory <- paste("c:\\AllShare\\", Sys.getenv("USERNAME"), sep = "")
dir.create(sql_share_directory, recursive = TRUE, showWarnings = FALSE)
sql <- RxInSqlServer(connectionString = connection_string, 
                     shareDir = sql_share_directory)
###################################################################################################
#Install packages and set up to connect to SQL DB via RSQLServer for retrieving tables
###################################################################################################
library("ggplot2") # Graphics
library("scales") # For time formatted axis

library(RSQLServer)
library(DBI)
#install.packages("RJDBC",dep=TRUE)
library(RJDBC)

library(dplyr)

####################################################################################################
## Telemetry metadata + summary stats
####################################################################################################
telemetry <- RxSqlServerData(table="telemetry", connectionString = connection_string)

rxImport(telemetry, numRows=10)
rxSummary( ~ ., telemetry)

##Plot subset of data in local 
theme_set(theme_bw())  # theme for figures

telemetry_df <- rxDataStep(inData = telemetry, rowSelection = machineID < 3)

telemetry_df$machineID <- as.factor(telemetry_df$machineID)
telemetry_df$datetime <- as.POSIXct(telemetry_df$datetime, format = "%Y-%m-%d %I:%M:%S", tz="UTC")

options(repr.plot.width = 8, repr.plot.height = 6)

ggplot(data = telemetry_df %>% filter(machineID=="1" | machineID=="2", datetime > ("2015-01-01"), datetime < ("2015-02-01")),
       aes(x = datetime, y = volt, col = factor(machineID))) +
  geom_line(alpha = 0.5) +
  labs(y = "voltage", color = "machineID") +
  facet_wrap(~machineID, ncol=1)

####################################################################################################
## Errors metadata + summary stats
####################################################################################################
errors <- RxSqlServerData(table="errors", connectionString = connection_string, 
                          colInfo = list( errorID = list(type = "factor", levels = c("error1", "error2","error3","error4","error5"))))
rxImport(errors, numRows=10)

errors_df <- rxDataStep(inData = errors)
rxSummary( machineID ~ errorID, errors_df)

#Plot histogram
rxHistogram( ~ errorID, data = errors_df, title = "Errors by type", xTitle = "error types", yTitle = "count")

# Plot data in local
errors_df$datetime <- as.POSIXct(errors_df$datetime, format = "%Y-%m-%d %I:%M:%S", tz="UTC")
errors_df$errorID <- as.character(errors_df$errorID)

options(repr.plot.width = 6, repr.plot.height = 5)
ggplot(errors_df %>% filter(machineID < 4), 
       aes(x = errorID, fill = factor(machineID))) + 
  geom_bar(color = "black") + 
  labs(title = "MachineID errors by type", x = "error types", fill="MachineID")+
  facet_wrap(~machineID, ncol = 1)

options(repr.plot.width = 7, repr.plot.height = 5)
ggplot(errors_df %>% filter(machineID == 4), 
       aes(y = errorID, x = datetime)) + 
  geom_point(color = "black", alpha = 0.5) + 
  labs(title = "MachineID 4 errors", x = "Date")

####################################################################################################
## Maintanence metadata + summary stats
####################################################################################################
maint <- RxSqlServerData(table="maint", connectionString = connection_string, 
                          colInfo = list( comp = list(type = "factor", levels = c("comp1", "comp2","comp3","comp4"))))
rxImport(maint, numRows=10)

maint_df <- rxDataStep(inData = maint)

# Plot histogram
rxHistogram( ~ comp, data = maint_df, title = "Component replacements", xTitle = "component types", yTitle = "count")

# Plot data in local
maint_df$comp <- as.character(maint_df$comp)
maint_df$machineID <- as.character(maint_df$machineID)
maint_df$datetime <- as.POSIXct(maint_df$datetime, format = "%Y-%m-%d %I:%M:%S", tz="UTC")

options(repr.plot.width = 6, repr.plot.height = 8)
ggplot(maint_df %>% filter(machineID == "1" | machineID == "2" | machineID == "3"), 
       aes(x = comp, fill = factor(machineID))) + 
  geom_bar(color = "black") +
  labs(title = "Component replacements", x = "component types", fill = "Machine ID")+
  facet_wrap(~machineID, ncol = 1)

options(repr.plot.width = 7, repr.plot.height = 5)
ggplot(maint_df %>% filter(machineID == "4"), 
       aes(y = comp, x = datetime)) + 
  geom_point(color = "black", alpha = 0.5) + 
  labs(title = "MachineID 4 component replacements", x = "Date")

####################################################################################################
## Machines metadata + summary stats
####################################################################################################
machines <- RxSqlServerData(table="machines", connectionString = connection_string, 
                         colInfo = list( comp = list(type = "factor", levels = c("model1", "model2","model3","model4"))))
rxImport(machines, numRows=10)

machines_df <- rxDataStep(inData = machines)

# Plot data in local
machines_df$model <- as.character(machines_df$model)

options(repr.plot.width = 8, repr.plot.height = 6)
ggplot(machines_df, aes(x = age, fill = model)) + 
  geom_bar(color = "black") + 
  labs(title = "Machines", x = "age (years)") +
  facet_wrap(~model) 

####################################################################################################
## Failure metadata + summary stats
####################################################################################################
failures <- RxSqlServerData(table="failures", connectionString = connection_string, 
                            colInfo = list( failure = list(type = "factor", levels = c("comp1", "comp2","comp3","comp4"))))
rxImport(failures, numRows=10)

failures_df <- rxDataStep(inData = failures)

rxSummary( machineID ~ failure, failures_df)

#Plot histogram
rxHistogram( ~ failure, data = failures, title = "Failure distribution", xTitle = "component types", yTitle = "count")

# Plot data in local
failures_df$failure <- as.character(failures_df$failure)
failures_df$machineID <- as.character(failures_df$machineID)

options(repr.plot.width = 6, repr.plot.height = 6)
ggplot(failures_df %>% filter(machineID == "1" |machineID == "2"| machineID == "3"),
       aes(x = failure, fill = factor(machineID))) + 
  geom_bar(color = "black") + 
  labs(title = "Failure distribution", x = "component type", fill = "MachineID") +
  facet_wrap(~machineID, ncol=1)

