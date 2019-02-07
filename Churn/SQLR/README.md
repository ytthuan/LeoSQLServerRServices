CUSTOMER CHURN TEMPLATE on MICROSOFT SQL SERVER ML SERVICES
----------------------------------------------------------

This template demonstrates how to build and deploy a customer churn prediction model in a retail scenario using [SQL Server ML Services](https://docs.microsoft.com/en-us/sql/advanced-analytics/r/sql-server-r-services). For a full description of the template, visit the [template](http://gallery.cortanaanalytics.com/Collection/Retail-Customer-Churn-Prediction-Template-1) in Cortana Analytics gallery.


REQUIREMENTS
------------

To run the scripts, you must prepare the following environment:

 * An instance of SQL Server 2016 CTP 3 or later, with SQL Server ML Services installed and configured
 * A SQL Server user and password. The SQL Server user must have permissions to execute R scripts
 * A database on the instance in which the user has been granted the permission to create and execute stored procedures
 
 * For more information about SQL Server ML Services, please visit:
   https://docs.microsoft.com/en-us/sql/advanced-analytics/what-s-new-in-sql-server-machine-learning-services
 
 
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

   
STEP 1: DATA PREPARATION
------------------------

The template requires two datasets as input: 

* User demographics info
* User shopping activities. 

We have provided sample datasets with this template, which can also be downloaded from [here](http://azuremlsamples.azureml.net/templatedata/RetailChurn_ActivityInfoData.csv) and [here](http://azuremlsamples.azureml.net/templatedata/RetailChurn_UserInfoData.csv).
The data schema for these files are described [here](http://gallery.cortanaanalytics.com/Experiment/Retail-Churn-Template-Step-1-of-4-tagging-data-1).

In this step, the user is first asked to enter the following information:

SQL Server Login credentials:

 * Server name (or its IP address): The SQL server instance name 
 
 * Database name: SQL database name. 
 
 * User name and password: The user credentials to access the SQL server.     

Model Parameters:

 * Churn period and threshold: These two parameters are used to identify churners and non-churners. The churn period are defined in the units of days (such as 30 days). The threshold refers to the number of activities (such as zero) . If within the length of churn period, the users whose numbers of activities is larger than the churn threshold are considered as non-churners, and otherwise as churners. 
 
Using the `bcp` utility, the script retrieves the users and activities files from the URL address and uploads them into the server. It then invokes `CreateDBTables.sql` to create the database with the following tables: 

<table style="width:85%">
  <tr>
    <th>Table</th>
    <th>Purpose</th>
  </tr>
  <tr>
    <td>Activities</td>
    <td>Customer activities</td>
  </tr>
  <tr>
    <td>Users</td>
    <td>Customer profiles</td>
  </tr>
    <td>ChurnVars</td>
    <td>Churn period and threshold</td>
  </tr>
    <td>ChurnModelR</td>
    <td>Churn model trained using open-source R</td>
  </tr>
  </tr>
    <td>ChurnModelRx</td>
    <td>Churn model trained using Microsoft ML Server</td>
  </tr>
    <td>ChurnPredictR</td>
    <td>Prediction results based on open-source R model</td>
  </tr>
  </tr>
    <td>ChurnPredictRx</td>
    <td>Prediction results based on Microsoft ML Server model</td>
</table>


STEP 2: DATA LABELING and FEATURE ENGINEERING
---------------------------

In the second step, `CreateFeatures.sql` and `CreateTag.sql` are invoked to create features,  and tags.

<table style="width:85%">
  <tr>
    <th>Script</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>CreateFeatures.sql</td>
    <td>Generate features: For textual fields (e.g., location, product category), calculate the number of unique values for each of the user; for the numeric fields (e.g., quantity, value), calculate the total aggregate and standard deviation for each of the user</td>
  </tr>
  <tr>
    <td>CreateTag.sql</td>
    <td>Label the users as churners or non-churners based churn period and churn threshold</td>
  </tr>
</table> 

 (labeling users as churner or non-churners). The output of these two scripts is stored in these tables: `Features` and `Tags`. For more details on feature engineering, visit this [link](http://gallery.cortanaanalytics.com/Collection/Retail-Customer-Churn-Prediction-Template-1).

STEP 3: MODEL TRAINING
------------------------------

In this step, `TrainModelR.sql` or `TrainModelRx.sql` are invoked to train the models on 70% of the data. The trained models are stored in `ChurnModelR` and `ChurnModelRx` tables.

<table style="width:85%">
  <tr>
    <th>Script</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>TrainModelR.sql</td>
    <td>Train model using open source R algorithms and packages </td>
  </tr>
  <tr>
    <td>TrainModelRx.sql</td>
    <td>Train model using Microsoft ML Server algorithms and packages (RevScaleR)</td>
  </tr>
</table> 

STEP 4: PREDICTION
----------------------------------

In this step, `PredictR.sql` or `PredictRx.sql` are invoked to make predictions with the models trained in the previous steps on the test data (30% of total data) and performance metrics is evaluated. Similarly to previous step, `PredictR.sql` uses the model trained with open source R packages, and make predictions with open source R packages, whereas `PredictRx.sql` uses the model trained using the Microsoft ML Server and predicts with the rx functions in RevScaleR package. 

The results are stored in a table with the following columns:

<table style="width:85%">
  <tr>
    <th>Column</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>UserId</td>
    <td>User Id</td>
  <tr>
    <td>Tag</td>
    <td>True customer status (churner or non-churner)</td>
  
  </tr>
    <td>Score</td>
    <td>Model score</td>
  </tr>
    <td>Auc</td>
    <td>Model AUC on test dataset (identical for all columns)</td>
  </tr>
</table>