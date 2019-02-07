This diretory contains R (Microsoft ML Server) codes for Energy Demand Forecasting Template with SQL Server 2016 R Services.  
The script main.R can be run from an R IDE, which will go through each step of the model development process of this template.  
The following scripts are included:

Script name|Description
-----------|-----------
dataPrepration.R|Fill missing data in the historical dataset
featureEngineering.R|Compute features including month of year, hour of day, weekday/weekend, linear trend, Fourier components, lag, etc.
trainModel.R|Train a Random Forest Regression model using the high performance analytics algorithm rxDForest in Microsoft ML Server (MRS)
main.R|Step by step demonstration of the model development process
