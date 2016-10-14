##########################################################################################################################################
## This R script will determine recommendations for each Lead_Id
## The goal is to determine, for each Lead_Id, the best combination of Day_of_Week, Channel, Time_Of_Day to target him.
## The best combination will be the one that was assigned the highest probability of conversion with the best model selected by scoring.

## This is done by doing the following: 
## 1. Create a full data table with  all the unique combinations of Day_Of_Week, Channel, Time_Of_Day. 
## 2. Compute the predicted probabilities for each Lead_Id, for each combination of Day_Of_Week, Channel, Time_Of_Day, using best_model.
## 3. For each Lead_Id, choose the combination of Day_Of_Week, Channel, Time_Of_Day that has the highest conversion probability.

## Input : Data set CM_AD and the best prediction model, best_model. 
## Output: Recommended Day_Of_Week, Channel and Time_Of_Day for each Lead_Id, to get a higher conversion rate.  

##########################################################################################################################################

## Compute Contexts and Packages

##########################################################################################################################################

# Load revolution R library and data.table. 
library(RevoScaleR)

# Compute Contexts.
connection_string <- "Driver=SQL Server; Server=[Server Name]; Database=Campaign_Management; UID=[User ID]; PWD=[User Password]"
sql <- RxInSqlServer(connectionString = connection_string)
local <- RxLocalSeq()

# Set the compute context to SQL. It will be changed to local whenever data is exported from R to SQL.
rxSetComputeContext(sql)


##########################################################################################################################################

## Input: - Point to the SQL table with the whole data set 
##        - Import the best model from the SQL server. 

##########################################################################################################################################

# Point to the SQL table holding the whole data set.
CM_AD <- RxSqlServerData(table = "CM_AD", connectionString = connection_string, stringsAsFactors = T)

# Import the fitted best model
if(best_model == "RF"){
  forest_model_char <- rxImport(forest_model_sql)
  forest_model_raw <- as.raw(strtoi(forest_model_char$x, 16))
  writeBin(forest_model_raw,con="forest_model.rds")
  best_model <- readRDS(file="forest_model.rds")
}

if(best_model == "GBT"){
  btree_model_char <- rxImport(btree_model_sql)
  btree_model_raw <- as.raw(strtoi(btree_model_char$x, 16))
  writeBin(btree_model_raw,con="btree_model.rds")
  best_model <- readRDS(file="btree_model.rds")
}


##########################################################################################################################################

## Create a full data table with all the unique combinations of Day_of_Week, Channel, Time_Of_Day 

##########################################################################################################################################

# Create a table with all the unique combinations of Day_of_Week, Channel, Time_Of_Day.
Day_of_Week_unique <- data.frame(seq(1, 7))
Channel_unique <-data.frame(c("Email", "Cold Calling", "SMS"))
Time_Of_Day_unique <- data.frame(c("Morning", "Afternoon", "Evening"))
Unique_Combos <- merge(merge(Day_of_Week_unique, Channel_unique), Time_Of_Day_unique)
colnames(Unique_Combos) <- c("Day_Of_Week", "Channel", "Time_Of_Day")

# Export it to SQL
rxSetComputeContext(local)
Unique_Combos_sql <- RxSqlServerData(table = "Unique_Combos_sql", connectionString = connection_string)
rxDataStep(inData = Unique_Combos, outFile = Unique_Combos_sql, overwrite = T)

# Change the compute context to sql in order to perform computations on the SQL table.
rxSetComputeContext(sql)

# We create a table that has, for each Lead_Id and its corresponding variables (except Day_of_Week, Channel, Time_Of_Day),
# One row for each possible combination of Day_of_Week, Channel and Time_Of_Day.
AD_full_merged_sql <- RxSqlServerData(
  sqlQuery = "SELECT * 
              FROM (
                    SELECT Lead_Id, Age, Annual_Income_Bucket, Credit_Score, State,No_Of_Dependents, Highest_Education, Ethnicity,
                    No_Of_Children, Household_Size, Gender, Marital_Status, Campaign_Id, Product_Id, Product, Term,
                    No_Of_People_Covered, Premium, Payment_Frequency, Amt_On_Maturity_Bin, Sub_Category,Campaign_Drivers,
                    Campaign_Name, Call_For_Action, Tenure_Of_Campaign,Net_Amt_Insured, SMS_Count, Email_Count,  Call_Count, 
                    Previous_Channel, Conversion_Flag
                    FROM CM_AD) a,
                    (SELECT * FROM Unique_Combos_sql) b",  stringsAsFactors = T, connectionString = connection_string, colInfo = column_info)

AD_full_merged <- RxSqlServerData(table = "AD_full_merged", stringsAsFactors = T, connectionString = connection_string, 
                                  colInfo = column_info)
rxDataStep(inData = AD_full_merged_sql, outFile = AD_full_merged, overwrite = TRUE)


##########################################################################################################################################

## Compute the predicted probabilities for each Lead_Id, for each combination of Day_of_Week, Channel, Time_Of_Day, using best_model

##########################################################################################################################################

# Score the full data by using the best model. Keep Lead_Id in the prediction table to be able to do an inner join with the full table.
score <- RxSqlServerData(table = "score", stringsAsFactors = T, connectionString = connection_string)
rxPredict(best_model, data = AD_full_merged, outData = score, overwrite = T, type = "prob",
          extraVarsToWrite = c("Lead_Id", "Day_Of_Week","Time_Of_Day","Channel"))

# Change the name of the variable 1_prob so it can be read by SQL.
renaming <- function(data){

  data <- as.data.frame(data)
  colnames(data)[2] <- c("X1_prob")
  return(data)
}

Prob_Id <- RxSqlServerData(table = "Prob_Id", stringsAsFactors = T, connectionString = connection_string)
rxDataStep(inData = score , outFile = Prob_Id, overwrite = TRUE, transformFunc = renaming)

# Add the probability column to the table AD_full_merged by doing an inner join.

AD_with_probability_query <- RxSqlServerData(  
  sqlQuery = "SELECT AD_full_merged.Lead_Id, AD_full_merged.Day_of_Week, AD_full_merged.Channel, AD_full_merged.Time_Of_Day,
              Prob_Id.X1_prob AS Prob1 
              FROM AD_full_merged JOIN Prob_Id
              ON  AD_full_merged.Lead_Id = Prob_Id.Lead_Id 
              AND AD_full_merged.Day_of_Week = Prob_Id.Day_of_Week 
              AND AD_full_merged.Channel = Prob_Id.Channel
              AND AD_full_merged.Time_Of_Day = Prob_Id.Time_Of_Day
              ORDER BY Lead_Id",
  connectionString = connection_string)
AD_with_probability = RxSqlServerData(table = "AD_with_probability", connectionString = connection_string)
rxDataStep(inData = AD_with_probability_query, outFile = AD_with_probability, overwrite = TRUE)


##########################################################################################################################################

## For each Lead_Id, choose a combination of Day_of_Week, Channel, and Time_Of_Day that has the highest conversion probability    

##########################################################################################################################################

Max_Probability <- RxSqlServerData(  
  sqlQuery = "SELECT Lead_Id, Day_of_Week, Channel, Time_Of_Day, MaxProb
              FROM (
                    SELECT maxp.Lead_Id, Day_of_Week, Channel, Time_Of_Day, MaxProb, 
                           ROW_NUMBER() OVER (partition by maxp.Lead_Id ORDER BY NEWID()) as RowNo
                    FROM ( SELECT Lead_Id, max(Prob1) as MaxProb
                           FROM AD_with_probability
                           GROUP BY Lead_Id) maxp
                    JOIN AD_with_probability 
                    ON (maxp.Lead_Id = AD_with_probability.Lead_Id AND maxp.MaxProb = AD_with_probability.Prob1)
              ) candidates
              WHERE RowNo = 1",
  connectionString = connection_string)

Recommended_Combinations <- RxSqlServerData(table = "Recommended_Combinations", connectionString = connection_string)
rxDataStep(inData = Max_Probability, outFile = Recommended_Combinations, overwrite = TRUE)

##########################################################################################################################################

## Add demographics information to the recommendation table  

##########################################################################################################################################

Recommendations_sql <- RxSqlServerData(
  sqlQuery = "SELECT Age, Annual_Income_Bucket, Credit_Score, Product, Campaign_Name as [Campaign Name], State,  
    Conversion_Flag as Converts,
	  CM_AD.Day_Of_Week as [Day of Week], CM_AD.Time_Of_Day as [Time of Day], CM_AD.Channel,
    CM_AD.Lead_Id as [Lead ID],
	  Recommended_Combinations.Day_Of_Week as [Recommended Day],
	  Recommended_Combinations.Time_Of_Day as [Recommended Time],
	  Recommended_Combinations.Channel as [Recommended Channel], Recommended_Combinations.MaxProb 
              FROM CM_AD JOIN Recommended_Combinations
              ON CM_AD.Lead_Id = Recommended_Combinations.Lead_Id",
  connectionString = connection_string)
Recommendations <- RxSqlServerData(table = "Recommendations", connectionString = connection_string)
rxDataStep(inData = Recommendations_sql, outFile = Recommendations, overwrite = TRUE)



