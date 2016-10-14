#Predictive Maintenance Template with SQL Server 2016 R Services 
------------------
   
 * **Introduction**
	 * **System Requirements**
	 * **Workflow Automation**
 * **Step 1: Data Preparation**
 * **Step 2: Feature Engineering**
 * **Step 3A: Train/test Regression Models**
 * **Step 3B: Train/test Binary Classification Models**
 * **Step 3C: Train/test Multi-class Classification Models**
 * **Step 4: Production Scoring**
 
##INTRODUCTION
------------

This template demonstrates how to build and deploy predictive maintenance models to predict asset failures using [SQL Server R Services](https://msdn.microsoft.com/en-us/library/mt674876.aspx). 
   
Three modeling solutions are provided in this template to accomplish the following tasks:

*	**Regression:** Predict the Remaining Useful Life (RUL) of an asset, or Time to Failure (TTF).
* **Binary classification:** Predict whether an asset will fail within a certain time frame (e.g. days). 
* **Multi-class classification:** Predict whether an asset will fail in any one of multiple time windows: For example, asset fails in window [1, w0] days; asset fails in the window [w0+1,w1] days; asset will not fail within w1 days. 

The time units mentioned above can be replaced by working hours, cycles, mileage, transactions, etc. based on the actual scenario. 

This template uses the example of simulated aircraft engine run-to-failure events to demonstrate the predictive maintenance modeling process. 
The implicit assumption of modeling data as done below is that the asset of interest has a progressing degradation pattern, which is reflected 
in the asset's sensor measurements. By examining the asset's sensor values over time, the machine learning algorithm can learn the relationship 
between the sensor values and changes in sensor values to the historical failures in order to predict failures in the future. We suggest examining 
the data format and going through all three steps of the template before replacing the data with your own.

This template is the on-prem equivalent of the implementation in Azure Machine Learning studio [here](https://gallery.cortanaanalytics.com/Collection/Predictive-Maintenance-Template-3), where more modeling details can be found.

The template is divided into three separate steps, and each step is implemented in **SQL Stored Procedures**. The R development code was directly wrapped within stored procedures. 

The SQL procedures can be executed in SQL Server environment (such as **SQL Server Management Studio**) and invoked by any applications. We demonstrated the end-to-end execution using a **PowerShell** script.

###SYSTEM REQUIREMENTS
------------

To run the scripts, you must prepare the following environment:

 * An instance of SQL Server 2016 (Enterprise or Developer edition) CTP 3 or later, with SQL Server R Services installed and configured
 * A SQL login and password. The SQL login must have permissions to execute R scripts
 * A database on the instance in which the login has been granted the permission to create and execute stored procedures
 
 * For more information about SQL Server 2016 and SQL Server R Services, please visit:
   https://msdn.microsoft.com/en-us/library/mt604847.aspx

###WORKFLOW AUTOMATION
-------------------

The following graph shows the overall work flow. The blue block represents each step of the PM template. Each step will interact with SQL server, either perform SQL table operations or invoking R through stored procedures.

![Architect of E2E work flow][1]   

The end-to-end workflow is fully automated by using a PowerShell script. To learn how to run the script, open a PowerShell command prompt, and type:

	Get-Help SQLR-Predictive-Maintenance.ps1 

To train and evaluate the models, you may run it as:

	SQLR-Predictive-Maintenance.ps1 -server [SQL Server instance name] -dbname [database name] 

To score the production data, you  may specify the -Score option:

	SQLR-Predictive-Maintenance.ps1 -server [SQL Server instance name] -dbname [database name] -Score

The following chart shows the workflow. In the chart, the blue parallelogram represents the action to take. Before each step, the user will have the choice to continue, skip or exit. 

![Work flow][2]
   
##STEP 1: DATA PREPARATION
------------------------

The first step is to create the tables in the specified database that are used for the training data, testing data, and trained models. The training data, testing data, and "ground truth" dataset provided as .CSV files in the current working directory. The corresponding tables in SQL Server are populated by using the ***bcp*** utility to bulk load the data from the files.  

After the raw data is uploaded into SQL tables, we will label the train and test data.

* For Regression models, adding column **RUL** to represent how many more cycles an in-service engine will last before it fails. 
* For Binary classification models, adding column **label1** to represent whether this engine is going to fail within **w1** cycles. 
* For Multi-class classification models, adding column **label2** to represent whether this engine is going to fail within the window [1, **w0**] cycles or to fail within the window **[w0+1, w1]** cycles, or it will not fail within **w1** cycles. We used the following values in the template: w1 = 30, w0 = 15.

The files used in this step are:

<table style="width:85%">
  <tr>
    <th>File</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>..\Data\PM_train.csv</td>
    <td>Raw training data, aircraft engine run-to-failure data</td>
  </tr>
  <tr>
    <td>..\Data\PM_test.csv</td>
    <td>Raw testing data, aircraft engine operating data without failure events recorded</td>
  </tr>
<tr>
    <td>..\Data\PM_truth.csv</td>
    <td>Ground truth data, containing the information for each engine in testing data</td>
  </tr>
  <tr>
    <td>DataProcessing\create_table.sql</td>
    <td>T-SQL script to create SQL table for train, test, truth and model tables</td>
  </tr>
  <tr>
    <td>DataProcessing\data_labeling.sql</td>
    <td>T-SQL script for data labeling</td>
  </tr>
</table>

**Output of this step:** Six tables are created in the SQL Server database:

* PM\_train: Table for training data
* PM\_test: Table for test data
* PM\_truth: Table containing "ground truth" data
* PM\_models: Table for storing trained models
* Labeled\_train\_data: Train data table with labels added
* Labeled\_test\_data: Test data table with labels added

##STEP 2: FEATURE ENGINEERING
---------------------------

This step focuses on data processing and feature engineering. The following tasks are performed in this step:

* **Feature engineering:**  Create aggregated features (such as rolling means and standard deviations), perform feature normalization.
 
The files related to this step are:

<table style="width:85%">
  <tr>
    <th>File</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>DataProcessing\feature_engineering.sql</td>
    <td>Stored procedure for feature engineering</td>
  </tr>
</table>

**Output of this step:** Four tables are created in the SQL Server database:

* train\_Features: Training data table with added features
* test\_Features: Testing data table with added features
* train\_Features\_Normalized: Normalized training data table with added features
* test\_Features\_Normalized: Normalized testing data table with added features
 
##STEP 3A: TRAIN AND EVALUATE REGRESSION MODELS
-------------------------------------
In this step, features are selected based on correlation, regression models are trained and evaluated, and the trained models are saved in the database. Scores and performance metrics that result from evaluating the model against the test data are also saved in the database. The regression models are created using these machine learning methods:

* Decision Forest Regression
* Boosted Decision Tree Regression
* Poisson Regression
* Neural Network Regression

The files related to this step are:

<table style="width:85%">
  <tr>
    <th>File</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>Regression\train_regression_model.sql</td>
    <td>Train Regression models</td>
  </tr>
  <tr>
    <td>Regression\test_regression_models.sql</td>
    <td>Evaluate models on test data and save scores and the performance metrics into SQL table</td>
  </tr>
</table>

**Output of this step:** 

* PM\_models table: Four rows will be added with one column for model\_name and another one to record the serialized trained model. 
	* regression\_rf: Name of model using Decision Forest Regression
	* regression\_btree: Name of model using Boosted Decision Tree Regression
	* regression\_glm: Name of model using Poisson Regression 
	* regression\_nn: Name of model using Neural Network Regression
* Regression\_prediction: Predictions for test data for each model
* Regression\_metrics: Metrics measured for each model 

##STEP 3B: TRAIN AND EVALUATE BINARY CLASSIFICATION MODELS
-------------------------------------

In this step, features are selected based on correlation, multiple binary classification models are trained and evaluated. The models are saved in the database after training. The scores and performance metrics from evaluating the trained models on test data are saved in the database as well. Models are trained using these four machine learning methods:

* Two-Class Logistic Regression
* Two-Class Boosted Decision Tree
* Two-Class Decision Forest
* Two-Class Neural Network

The files related to this step are:

<table style="width:85%">
  <tr>
    <th>File</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>BinaryClassification\train_binaryclass_model.sql</td>
    <td>Train Binary Classification model</td>
  </tr>  
  <tr>
    <td>BinaryClassification\test_binaryclass_models.sql</td>
    <td>Test models and save the performance metrics into SQL tables</td>
  </tr>
</table>

**Output of this step:** 

* PM\_models table: Four rows will be added, with one column for model\_name and another one to record the serialized trained model. 
	* binaryclass\_rf: Name of model using Two-Class Logistic Regression
	* binaryclass\_btree: Name of model using  Two-Class Boosted Decision Tree
	* binaryclass\_logit: Name of model using  Two-Class Decision Forest 
	* binaryclass\_nn: Name of model using for Two-Class Neural Network
* Binaryclass\_prediction: Predictions for test data for each model
* Binaryclass\_metrics: Metrics measured for each model

##STEP 3C: TRAIN/TEST MULTI-CLASS CLASSIFICATION MODELS
-------------------------------------
In this step, features are selected based on correlation, multiple multi-class classification models are trained and evaluated. The models are saved in the database after training. The scores and performance metrics from evaluating the trained models on test data are saved in the database as well.

In this step, we train and evaluate two multi-class classification models, using these algorithms: 

* Multi-class Decision Forest 
* Multi-class Neural Network

We also train and evaluate two ordinal regression models using the Two-Class Logistic Regression and Two-Class Neural Network algorithms as the base model:

* Ordinal regression models using Two-Class Logistic Regression
* Ordinal regression models using Two-Class Neural Network

The files related to this step are:

<table style="width:85%">
  <tr>
    <th>File</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>MultiClassification\train_multiclass_model.sql</td>
    <td>Train Multi-class Classification models</td>
  </tr>  
  <tr>
    <td>MultiClassification\test_multiclass_models.sql</td>
    <td>Evaluate models on test data and save the scores and performance metrics into SQL tables</td>
  </tr>
</table>

**Output of this step:** 

* PM\_models table: Four rows will be added with one column for model\_name and another one to record the serialized trained model.
	* multiclass\_rf: Name of model using Multiclass Decision Forest
	* multiclass\_btree: Name of model using Ordinal regression on Two-Class Logistic Regression
	* multiclass\_nn: Name of model using Multiclass Neural Network 
	* multiclass\_mn: Name of model using Ordinal regression on Two-Class Neural Network
* Multiclass\_prediction: Predictions for test data for each model
* Multiclass\_metrics: Metrics measured for each model
 
##STEP 4: Production Scoring

In this step, we show how we call the stored procedures to make predictions on new data. For demo purpose, the data used for scoring is taken from testing dataset with engine id as 2 and 3.
 
**Step1:  Call the data preparation SQL script:** 
   If data is local CSV file, do the follwing: 
	
* create PM_Score table in SQL Server using DataProcessing\create\_table\_score.sql
* Upload the data to PM_Score table using bcp utility

**Output:** SQL table PM\_score, the raw data for scoring

**Step2. Call the feature engineering SQL script:** DataProcessing\feature\_engineering\_scoring.sql
	
**Output:** SQL table score\_Features\_Normalized, the data with new features and normalized

**Step 3a. Call the Regression model SQL script:** Regression\score\_regression\_model.sql
	
**Output:** SQL table Regression\_score\_[model\_name], scoring result for regression model

**Step 3b. Call the SQL script for Binary classification model:** BinaryClassification\score\_binaryclass\_model.sql
	
**Output:** SQL table Binaryclass\_score\_[model\_name], scoring result for binaryclassification model

**Step 3c. Call the SQL script for Multiclass classification model:** MultiClassification\score\_multiclass\_model.sql
	
**Output:** SQL table Multiclass\_score\_[model\_name], scoring result for multiclass classification model

[1]: workflow_architect.png
[2]: workflow_automation.png
