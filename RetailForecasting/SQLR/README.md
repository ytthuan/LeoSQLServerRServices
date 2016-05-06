#Retail Forecasting Template with SQL Server 2016 R Services 
------------------
   
 * **Introduction**
	 * **System Requirements**
	 * **Workflow Automation**
 * **Step 1: Data Preprocessing**
 * **Step 2: Train Time Series Models**
 * **Step 3: Feature Engineering for Regression Models**
 * **Step 4: Train Regression Models**
 * **Step 5: Test/Evaluate Regression Models**
 * **Step 6: Production Scoring**
 
##INTRODUCTION
------------

This template demonstrates how to build a pipeline that automatically provides weekly retail forecasts of the next 52 weeks for each store and each product using [SQL Server R Services.](https://msdn.microsoft.com/en-us/library/mt674876.aspx). 
   
Two modeling solutions are provided for this template :

* **Time Series Forecasting:** 
	* Seasonal Trend Decomposition using Loess (STL) + Exponential Smoothing (ETS);
	* Seasonal Naive;
	* Seasonal Trend Decomposition using Loess + AutoRegressive Integrated Moving Average (ARIMA).
* **Regression Models:** 
	* Boosted Decision Tree Regression
	* Random Forest Regression

This template is the on-prem equivalent of the implementation in Azure Machine Learning studio [here](https://gallery.cortanaintelligence.com/Experiment/Retail-Forecasting-Step-1-of-6-data-preprocessing-5), where more modeling details can be found.

The template is divided into five separate steps, and each step is implemented in **SQL Stored Procedures**. The R development code was directly wrapped within stored procedures. 

The SQL procedures can be executed in SQL Server environment (such as **SQL Server Management Studio**) and invoked by any applications. We demonstrated the end-to-end execution using a **PowerShell** script.

###SYSTEM REQUIREMENTS
------------

To run the scripts, you must prepare the following environment:

 * An instance of SQL Server 2016 CTP 3 or later, with SQL Server R Services installed and configured
 * A SQL login and password. The SQL login must have permissions to execute R scripts
 * A database on the instance in which the login has been granted the permission to create and execute stored procedures
 
 * For more information about SQL Server 2016 and SQL Server R Services, please visit:
   https://msdn.microsoft.com/en-us/library/mt604847.aspx

###WORKFLOW AUTOMATION
-------------------

The end-to-end workflow is fully automated by using a PowerShell script. To learn how to run the script, open a PowerShell command prompt, and type:

	Get-Help SQLR-Retail-Forecasting.ps1 

To train and evaluate the models, you may run it as:

	SQLR-Retail-Forecasting.ps1 -server [SQL Server instance name] -dbname [database name] 

After the command, it will ask you for the SQL login name and password. This information will be used to construct the SQL connection string and pass it to various SQL stored procedure. 
   
##STEP 1: DATA PREPROCESSING
------------------------

The first step is to create the tables in the specified database that are used for the training data, testing data, and trained models. The original dataset is provided as .CSV files in the Data directory. The corresponding tables in SQL Server are populated by using the ***bcp*** utility to bulk load the data from the files.  

After the raw data is uploaded into SQL tables, the data will be processed:

 * Select an eligible time series, based on pre-defined business rules. This template demonstrates two possible rules:
 
	* If a time series is too short to provide enough historical information, discard it. Here, we only consider  time series longer than two years.
	* If a time series has any sales quantity less than a certain threshold, discard it. For instance, we only consider products having sales quantity larger than 20

* Create a complete time series by inserting any time stamps that are missing between the earliest and latest times in the data. You can replace the corresponding missing data values with NA.

* Select a time series based on the goodness of training and testing data. Discard a time series if the last six values in training data set are all missing or more than half of the testing data are missing.

The files used in this step are:

<table style="width:85%">
  <tr>
    <th>File</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>..\Data\forecastinput.csv</td>
    <td>Raw retail data</td>
  </tr>
  <tr>
    <td>..\Data\forecasting_personal_income.csv</td>
    <td>Economic index of real disposable personal income</td>
  </tr>
</table>

**Output of this step:** Three tables are created in the SQL Server database:

<table style="width:85%">
  <tr>
    <th>Table</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>forecastinput</td>
    <td>Table for raw retail time series data</td>
  </tr>
  <tr>
    <td>forecasting_personal_income</td>
    <td>Table for real disposable personal income economic index</td>
  </tr>
  <tr>
    <td>forecasting</td>
    <td>Preprocessed dataset</td>
  </tr>
</table>

##STEP 2: TRAIN TIME SERIES MODELS
---------------------------

This step focus on fitting the time series model which includes:

* Seasonal Trend Decomposition using Loess (STL) + Exponential Smoothing (ETS). Note that STL won’t work when seasonality equals 1. In this case, you should use R’s ets function instead. 

* Seasonal Naive. Note that seasonal naïve won’t work when seasonality equals to 1. In this case, you should use R’s naïve function instead. 

* Seasonal Trend Decomposition using Loess + AutoRegressive Integrated Moving Average (ARIMA). Note that STL won’t work when seasonality equals 1. In this case, use R’s auto.arima function instead. 
 
The files to be used in this step include:

<table style="width:85%">
  <tr>
    <th>File</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>DataProcessing\time_series_forecasting.sql</td>
    <td>SQL Stored procedure for training time series models</td>
  </tr>
</table>

**Output of this step:** Four tables are created in the SQL Server database:

<table style="width:85%">
  <tr>
    <th>Table</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>metrics_[model name]*</td>
    <td>Metrics of the selected model</td>
  </tr>
  <tr>
    <td>forecast_[environment]_[model name]**</td>
    <td>Forecasting of the selected model</td>
  </tr>
</table>

Note: 

* * The values of [model name] will be one of "ets", "snaive" or "arima"
* ** The values of [environment] will be one of "test" or "prod". "test" means for testing and "prod" means for production.

 
##STEP 3: FEATURE ENGINEERING
-------------------------------------
In this step, the features will be created for regression models. The following is the list of features we will create.

* Create features using the external economic index. Here, we use Real Disposable Personal Income as an example. As a leading indicator, this index changes before sales change. We will select the best lag of this index based on maximum correlation. 

* Create features based on date time. The following features will be created:

	* Date features: year, month, week of month, etc.
	* Time features
	* Season features
	* Weekday-and-weekend features
	* Holiday features: New Year, U.S. Labor Day, U.S. Thanksgiving, Cyber Monday, Christmas, etc.
	* Fourier features to capture seasonality

* Create lag features for training and testing data. Here the lag values are from 1 to 26.

After all the features are created, save it into SQL table "features" for later reference.



The files related to this step are:

<table style="width:85%">
  <tr>
    <th>File</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>feature_engineering.sql</td>
    <td>Create features</td>
  </tr>
  <tr>
    <td>generate_train.sql</td>
    <td>Adding lag values for train data</td>
  </tr>
  <tr>
    <td>generate_test.sql</td>
    <td>Adding lag values for test data</td>
  </tr>
</table>

**Output of this step:** Multiple tables will be created in the SQL Server database:

<table style="width:85%">
  <tr>
    <th>Table</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>features</td>
    <td>The dataset with created features</td>
  </tr>
  <tr>
    <td>train</td>
    <td>train dataset with complete feature set</td>
  </tr>
  <tr>
    <td>test</td>
    <td>test dataset with complete feature set</td>
  </tr>
  <tr>
    <td>train_fold[number]*</td>
    <td>one set of random sampled train data</td>
  </tr>
</table>

Note: * the model will be trained with multi-fold.

##STEP 4: TRAIN REGRESSION MODELS
-------------------------------------

In this step, regression models are trained and saved in the database after training. The scores and performance metrics from evaluating the trained models on test data are saved in the database as well. Models are trained using these two machine learning methods:

* Boosted Decision Tree Regression
* Random Forest Regression

The files related to this step are:

<table style="width:85%">
  <tr>
    <th>File</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>train_regression_btree.sql</td>
    <td>Train Boosted Decision Tree Regression model</td>
  </tr>
  <tr>
    <td>train_regression_rf.sql</td>
    <td>Train Radom Forest Regression model</td>
  </tr>
</table>

**Output of this step:** 

<table style="width:85%">
  <tr>
    <th>Table</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>RetailForecasting_models_btree</td>
    <td>the trained model with Boosted Decision Tree Regression</td>
  </tr>
  <tr>
    <td>RetailForecasting_models_rf</td>
    <td>the trained model with Random Forest Regression</td>
  </tr>
</table>

##STEP 5: TEST REGRESSION MODELS
-------------------------------------

In this step, regression models are trained and saved in the database after training. The results and performance metrics from evaluating the trained models on test data are saved in the database as well. 
The files related to this step are:

<table style="width:85%">
  <tr>
    <th>File</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>test_regression_models.sql</td>
    <td>Test and evalute the regression models</td>
  </tr>
</table>

**Output of this step:** 
<table style="width:85%">
  <tr>
    <th>Table</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>regression_forecasts</td>
    <td>Test result of the forecasting</td>
  </tr>
  <tr>
    <td>regression_forecasts_metrics</td>
    <td>The metrics evaluated with regression models</td>
  </tr>
</table>

##STEP 6: Production Scoring

In this step, we show how we call the stored procedures to make predictions on new time series data. For demo purpose, the data used for scoring is taken from testing dataset with ID1 as 2 ID2 as 1, and the horizon value as 4, ie. predicting the next four weeks sales for store ID1 for product ID2. The decision forest regression model is selected for scoring. The parameter of the model, number of trees and max depth are taken from the table [forest_sweep] with the minimum Mean Absolute Error values. 
 
**Step 1:  Call the data preprocessing SQL script:** data_preprocess_score.sql

**Output:** SQL table [forecasting] contains the complete time series including both training and to be scored time series data 

**Step 2: Call the time series forecating SQL script:** time_series_forecasting.sql
	
**Output:** SQL table [Score_arima], the time series forecasting with arima model

**Step 3: Call the feature engineering stored procedure :** feature_engineering.sql
	
**Output:** SQL table [features], the complete features for both training and scoring time series data

**Step 4: Call the SQL script to generate training dataset:** generate_train.sql
	
**Output:** SQL table [train], the training dataset used to train the regression model

**Step 5: Call the SQL script to generate testing dataset:** generate_test.sql
	
**Output:** SQL table [test], the scoring dataset used for prediction

**Step 6: Call the SQL script for scoring:** score_regression_rf.sql
	
**Output:** SQL table Multiclass\_score\_[model\_name], scoring result for multiclass classification model