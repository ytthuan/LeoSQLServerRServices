CUSTOMER CHURN TEMPLATE on MICROSOFT SQL SERVER ML SERVICES
----------------------------------------------------------

This template demonstrates how to build and deploy a customer churn prediction model in a retail scenario using [SQL Server ML Services](https://docs.microsoft.com/en-us/sql/advanced-analytics/r/sql-server-r-services). Predicting customer churn is an important problem for banking, telecommunications, retail and many others customer related industries. Microsoft is providing this template to help retail companies predict customer churns. This template focuses on binary churn prediction, i.e. classifying the users as churners or non-churners.

For more information about SQL Server ML Services, please visit: https://docs.microsoft.com/en-us/sql/advanced-analytics/what-s-new-in-sql-server-machine-learning-services

REQUIREMENTS
------------

To run the scripts, you must prepare the following environment:

 * An instance of SQL Server 2016 CTP 3 or later, with SQL Server ML Services installed and configured
 * A SQL Server user and password. The SQL Server user must have permissions to execute R scripts
 * A database on the instance in which the user has been granted the permission to create and execute stored procedures
 
WORKFLOW
-------------------

The template demonstrates the following steps in building the customer churn model with SQL Server ML Services:

* Data uploading
* Data processing (tagging)
* Feature engineering
* Model training
* Prediction (Scoring)
* Model performance evaluation
 
We provide a Windows Powershell script to demonstrate the end-to-end workflow. The script can be invoked remotely from the PowerShell console by running the following command from the directory where the source files have been downloaded:

	SQLR-Customer-Churn.ps1  -ServerName <String> -DBName <String> [-ChurnPeriodVal <Int32>] [-ChurnThresholdVal <Int32>] [<CommonParameters>]

The PowerShell script invokes a number of SQL scripts through the steps described below. Each step can be also skipped if not needed. The PowerShell script is mainly provided as a convenient way for the user to deploy the template. An experienced user may directly run, modify or integrate the provided SQL scripts in SQL Server Client application (e.g., SQL Server Management Studio).
An automated script, designed to run without user interaction is provided in `CustomerChurnSetup.ps1`.

   
STEP 1: DATA PREPARATION
------------------------

The template requires two datasets as input: 

* User demographics info
* User shopping activities. 

Any data following the schema of the User Information Data set and the Activity Data set can be used with the churn template. Furthermore, this churn Template is generalized to handle different churn definitions on the granularity of number of days as input. 
Schema of User Information Data is shown in the following table:

|Index|Data Fields|Type|Description|Required|
|-|-|-|-|-|
|1|UserId|String|Unique User Id|X|
|2|Age|String|Age of the User.||
|3|Address|String|Address of the User.||
|4|Gender|String|Gender of the User.||
|5|UserType|String|Type of the User.||

Similarly, schema of Activity Data is shown in the following table:

|Index|Data Fields|Type|Description|Required|
|-|-|-|-|-|
|1|TransactionId|String|Unique Transaction Id|X|
|2|Timestamp|String|Timestamp of the transaction specified in the format yyyy/mm/dd hh:mm|X|
|3|UserId|String|Id of the User making the transaction|X|
|4|ItemId|String|Id of the Item being purchased|X|
|5|Quantity|Int|Number of Items purchased by the User|X|
|6|Value|Double|Value of the complete transaction|X|
|7|Location|String|Location at which transaction was made||
|8|ProductCategory|String|Type of Item being purchased||

Some of the fields like Gender and UserType are having "Unknown" value because they were not available in this data set. This template is designed to be generalized so it works regardless of the availability of the optional fields. Furthermore, this template depends on the definition of the Churn which has to be provided by the user as shown in the following figure

In this step, the user is first asked to enter the following information:

SQL Server Login credentials:

 * Server name (or its IP address): The SQL server instance name 
 
 * Database name: SQL database name. 
 
 * User name and password: The user credentials to access the SQL server.     

Model Parameters:

 * Churn period and threshold: These two parameters are used to identify churners and non-churners. The churn period are defined in the units of days (such as 30 days). The threshold refers to the number of activities (such as zero) . If within the length of churn period, the users whose numbers of activities is larger than the churn threshold are considered as non-churners, and otherwise as churners. 
 
Using the `bcp` utility, the script retrieves the users and activities files from the URL address and uploads them into the server. It then invokes `CreateDBTables.sql` to create the database with the following tables: 

|Table|Purpose|
|-|-|
|Activities|Customer activities|
|Users|Customer profiles|
|ChurnVars|Churn period and threshold|
|ChurnModelR|Churn model trained using open-source R|
|ChurnModelRx|Churn model trained using Microsoft ML Server|
|ChurnPredictR|Prediction results based on open-source R|
|ChurnPredictRx|Prediction results based on Microsoft ML Server model|


STEP 2: DATA LABELING and FEATURE ENGINEERING
---------------------------

In the second step, `CreateFeatures.sql` and `CreateTag.sql` are invoked to create features,  and tags.

|Script|Description|
|-|-|
|CreateFeatures|Generate features: For textual fields (e.g., location, product category), calculate the number of unique values for each of the user; for the numeric fields (e.g., quantity, value), calculate the total aggregate and standard deviation for each of the user|
|CreateTag.sql|Label the users as churners or non-churners based churn period and churn threshold.|


 In this step we labels users as churner or non-churners. The output of these two scripts is stored in these tables: `Features` and `Tags`. The tagged input data to this experiment consists of some fields (numeric fields) for which we may be interested in total sum ( for example: Quantity, Value etc) while for some others (textual/string fields) we may be interested in counting the number of unique entries ( for example, Location, Address, Product Category). This observation is the basis of the Feature Generation process that we have developed. For textual fields we are interested in calculating the number of unique values for each of the user while for the numeric features we are interested in calculating the total aggregate and standard deviation for each of the user. 

STEP 3: MODEL TRAINING
------------------------------

In this step, `TrainModelR.sql` or `TrainModelRx.sql` are invoked to train the models on 70% of the data. The trained models are stored in `ChurnModelR` and `ChurnModelRx` tables.

|Script|Description|
|-|-|
|TrainModelR.sql|Train model using open source R algorithms and packages|
|TrainModelRx.sql|Train model using Microsoft ML Server algorithms and packages (RevScaleR)|

STEP 4: PREDICTION
----------------------------------

In this step, `PredictR.sql` or `PredictRx.sql` are invoked to make predictions with the models trained in the previous steps on the test data (30% of total data) and performance metrics is evaluated. Similarly to previous step, `PredictR.sql` uses the model trained with open source R packages, and make predictions with open source R packages, whereas `PredictRx.sql` uses the model trained using the Microsoft ML Server and predicts with the rx functions in RevScaleR package. 

The results are stored in a table with the following columns:

|Column|Description|
|-|-|
|UserId|User Id|
|Tag|True customer status (churner or non-churner)|
|Score|Model score|
|Auc|Model AUC on test data set (identical for all columns)|