##########################################################################################################################################
## This R script will do the following:
## 1. Create pointers pointing to the 4 data sets on HDFS: Campaign_Detail.csv, Lead_Demography.csv, Market-Touchdown.csv, and Product.csv.
## 2. Join the 4 datasets into one.
## 2. Clean the merged data set: replace NAs with the mode for categorical variables, and with the mean for numerical ones.

## Input : 4 Data files: Campaign_Detail.csv, Lead_Demography.csv, Market-Touchdown.csv, and Product.csv.
## Output: Cleaned raw data set CM_AD0.

##########################################################################################################################################

## Compute Contexts and Packages

##########################################################################################################################################

# Load revolution R library and data.table. 
library(RevoScaleR)

# Compute Contexts
hdfs <- RxHdfsFileSystem()
myHadoopCluster <- RxSpark()

# The default directory on local edge node and HDFS
myShareDir <- paste( "/var/RevoShare", Sys.info()[["user"]],sep="/" ) 
HDFSDir <- paste("/CampaignManagement", Sys.info()[["user"]],sep="/")

rxSetComputeContext('local')

##########################################################################################################################################

## load 'SparkR' package, set context as SQLContext to perform join on data files

##########################################################################################################################################

if (nchar(Sys.getenv("SPARK_HOME")) < 1) {
  Sys.setenv(SPARK_HOME = "/home/spark")
}
library(SparkR, lib.loc = c(file.path(Sys.getenv("SPARK_HOME"), "R", "lib")))

sparkEnvir <- list(spark.executor.instances = '10',
                   
                   spark.yarn.executor.memoryOverhead = '8000')



sc <- sparkR.init(
  
  sparkEnvir = sparkEnvir,
  
  sparkPackages = "com.databricks:spark-csv_2.10:1.5.0"
  
)

sqlContext <- sparkRSQL.init(sc)

Campaign_Detail <- read.df(sqlContext,"/CampaignManagement/Campaign_Detail1k.csv","csv",header = "true")

Lead_Demography <- read.df(sqlContext,"/CampaignManagement/Lead_Demography1k.csv","csv",header = "true")

Market_Touchdown <- read.df(sqlContext,"/CampaignManagement/Market_Touchdown1k.csv","csv",header = "true")

Product <- read.df(sqlContext,"/CampaignManagement/Product1k.csv","csv",header = "true")


registerTempTable(Campaign_Detail, "Campaign_Detail")

registerTempTable(Lead_Demography, "Lead_Demography")

registerTempTable(Market_Touchdown, "Market_Touchdown")

registerTempTable(Product, "Product")

Campaign_Product <- sql(sqlContext, 
                        
                        "SELECT Campaign_Detail.*, Product.Product, Product.Term, Product.No_of_people_covered, Product.Premium, 
                        
                        Product.Payment_frequency, Product.Net_Amt_Insured, Product.Amt_on_Maturity, Product.Amt_on_Maturity_Bin
                        
                        FROM Campaign_Detail 
                        
                        INNER JOIN Product
                        
                        ON Product.Product_Id = Campaign_Detail.Product_Id ")

#This is another way of joining with all data fields.
#Campaign_Product <- SparkR::join(Campaign_Detail, Product, "Product.Product_Id = Campaign_Detail.Product_Id", joinType="inner")

Market_Lead <- sql(sqlContext,
                   
                   "SELECT Lead_Demography.*, Market_Touchdown.Channel, Market_Touchdown.Time_Of_Day, Market_Touchdown.Conversion_Flag,
                   
                   Market_Touchdown.Campaign_Id, Market_Touchdown.Day_Of_Week, Market_Touchdown.Comm_Id
                   
                   FROM Market_Touchdown 
                   
                   INNER JOIN Lead_Demography
                   
                   ON Market_Touchdown.Lead_Id = Lead_Demography.Lead_Id")



# register Dataframes as tables

registerTempTable(Campaign_Product, "Campaign_Product")

registerTempTable(Market_Lead, "Market_Lead")


# Inner join of the two previous tables.

Campaign_Product_Market_Lead <- sql(sqlContext,
                                    
                                    "SELECT Market_Lead.*, Campaign_Product.Product, Campaign_Product.Category, Campaign_Product.Term, 
                                    
                                    Campaign_Product.No_of_people_covered, Campaign_Product.Premium, Campaign_Product.Payment_frequency, 
                                    
                                    Campaign_Product.Amt_on_Maturity, Campaign_Product.Sub_Category, Campaign_Product.Campaign_Drivers, 
                                    
                                    Campaign_Product.Campaign_Name, Campaign_Product.Call_For_Action, 
                                    
                                    Campaign_Product.Focused_Geography, Campaign_Product.Tenure_Of_Campaign, Campaign_Product.Net_Amt_Insured, 
                                    
                                    Campaign_Product.Product_Id
                                    
                                    FROM Campaign_Product 
                                    
                                    INNER JOIN Market_Lead 
                                    
                                    ON Campaign_Product.Campaign_Id = Market_Lead.Campaign_Id ")


joinedDF <- repartition(Campaign_Product_Market_Lead, 10)

write.df(joinedDF, paste(HDFSDir, "/full_merged", sep=""),"com.databricks.spark.csv",  mode = "overwrite", header="true")

#remove non-data file
rxHadoopRemove(paste(HDFSDir, "/full_merged/_SUCCESS", sep=""))

# stop sparkR
# if not stop sparkR session, training with spark cc in mrs will be very very slow
sparkR.stop()

# change .csv files to xdf file
joinedDFTxt <- RxTextData(paste(HDFSDir, "/full_merged", sep=""),
                          fileSystem = hdfs)
Merged <- RxXdfData(paste(HDFSDir, "/MergedXdf", sep=""), fileSystem = hdfs)
rxDataStep(inData = joinedDFTxt, Merged, overwrite = TRUE)

##########################################################################################################################################

## Clean the Merged data set: 
## Replace NAs with the mode.

##########################################################################################################################################
# Assumption: there are no NAs in the Id variables (Lead_Id, Product_Id, Campaign_Id)
# Function to deal with NAs. 
Mode_Replace <- function(data) {
  data <- data.frame(data)
  var <- colnames(data)[! colnames(data) %in% c("Lead_Id", "Phone_No", "Campaign_Id", "Comm_Id", "Product_Id")]
  for(j in 1:length(var)){
    row_na <- which(is.na(data[, var[j]]) == TRUE) 
    if(length(row_na) > 0){
      xtab <- base::table(data[,var[j]])
      mode <- names(which(xtab==max(xtab)))
      if(is.character(data[, var[j]]) | is.factor(data[, var[j]])){
        data[row_na, var[j]] <- as.character(mode)
      } else{
        data[row_na, var[j]] <- as.integer(mode)
      }
    }
  }
  return(data)
}


Merged_df <- rxImport(Merged)
Merged_df_new <- Mode_Replace(Merged_df)

# Create the CM_AD0 Xdf file by dealing with NAs in Merged and save it to HDFS.
CM_AD0 <- RxXdfData(file = paste(HDFSDir, "/CMAD0Xdf", sep=""),fileSystem = hdfs)
rxDataStep(inData = Merged_df_new, outFile = CM_AD0, overwrite = TRUE)  
