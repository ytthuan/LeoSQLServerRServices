<img src="../Images/management.png" align="right">
<h1>Campaign Management:
Execution with SQLR Scripts</h1>


For the purposes of a quick demo, we can use a small dataset. To create a smaller dataset follow the steps in <a href="Data_Setup.md">Data Setup</a>.

Make sure you have set up your SQL Server and ODBC connection between SQL and PowerBI by following the instructions in <a href="START_HERE.md">START HERE</a>.  Then proceed with the steps below to run the solution template using the automated PowerShell files. 


Running these .sql scripts will walk through the operationalized steps of this solution  – dataset creation, modeling, and scoring as described  [here](../data-scientist.md).

<h2>Solution Path:  SQLR Scripts</h2>
The steps below walk you through the execution each of the SQLR scripts - see the [SQLR directory readme](../../SQLR/readme.md) for a detailed description of each of these scripts.

Let’s start in SQL Server Management Studio where we have connected to the SQL 2016 server.  
Login to SSMS using the credential created in [START HERE](START_HERE.md).

The first step we need to do is import the raw datasets into the SQL Server. In this solution we will use PowerShell to import the raw datasets into SQL Server.  
 

1.	Click on the windows key on your keyboard. Type the words `PowerShell ISE` and open the Windows PowerShell ISE app.
<br/>
<img src="../Images/ps1.png" width="30%" >

2.	In the Powershell ISE command window, type the following command:
 ```
 Set-ExecutionPolicy Unrestricted -Scope Process
 ```
Answer `y` to the prompt to allow the following scripts to execute.

3.	Click on File on the top left corner of the screen. Then click on Open and navigate to the folder location where you unzipped the CampaignManagement.zip file and open `Data Import.ps1`.

4.	Press `F5` to run the PowerShell script.

 You will get a warning here saying that you should only run scripts you trust.

5.	Hit `Run Once`.

 The command line window will prompt you to enter the Server Name.

6.	Enter your Machine Name. If you do not know your Machine Name follow instructions from the [START HERE](START_HERE.md) Instructions.

 The command line window will prompt you to enter the Database Name.

7.	Enter `CampaignManagement`.

 The command line window will prompt you to enter the Schema Name.

8.	Enter `dbo`.

 The command line window will prompt you to enter your Username and Password. 

9.	Enter Your UserName & Password that you created earlier using the Set up Instructions document.

 The command line window will prompt you to enter the Full Path of the Data Location.

10.	Enter the full path of the folder you extracted the CampaignManagement.zip file (`C:\Demos\CampaignManagement`)
 <br/>
 <img src="../Images/sqlr10.png" > 
	 

11.	Logon to SSMS using the credentials you created earlier. 

 Follow the path shown in the image below and verify that the input datasets are created.
 <br/>
 <img src="../Images/sqlr11.png" width="40%"> 

 All the required input data sets have been created. Now we can move on to preprocessing the input datasets.

<h2>Preprocessing</h2>

12.	Open a new Query and type `USE CampaignManagement` into the query and `Execute`
 <br/>
 <img src="../Images/sqlr12.png" width="75%"> 

13.	Open `step2(a)_preprocessing_market_touchdown.sql` and click on `Execute`.

 This step creates the treats the market touchdown dataset for outliers
 <br/>
 <img src="../Images/sqlr13.png" width="75%"> 


14.	Open 2.	`step2(b)_preprocessing_lead_demography.sql` and click on `Execute`.

 This step creates the treats the target demography dataset for missing values.
 <br/>
 <img src="../Images/sqlr14.png" width="75%"> 

<h2>Feature Engineering</h2>

 Once the preprocessing is done, it’s now time to perform feature engineering on the market touchdown dataset.

15.	Open `step3_feature_engineering_market_touchdown.sql` and click on `Execute`.

 This step creates the new variables in the market touchdown dataset by aggregating the data in multiple levels.  The table is aggregated at a lead level, so variables like channel which will have more than one value for each user are pivoted and aggregated to variables like SMS count, Email count, Call Count, Last Communication Channel, Second Last Communication Channel etc. 
<br/>
<img src="../Images/sqlr15.png" width="75%"> 

 Take a look at the features created by running the following query in SSMS:
 ```
 SELECT TOP 1000 [Lead_Id]
      ,[Sms_Count]
      ,[Email_Count]
      ,[Call_Count]
      ,[Last_Channel]
      ,[Second_Last_Channel]
  FROM [CampaignManagement].[dbo].[market_touchdown_agg]
  ```

 Now that the feature engineering step is complete, we can now join all the input datasets to create the analytical dataset.

16.	Open `step4_ad_creation.sql` and click on `Execute`.

 This step merges the processed input datasets to create the analytical dataset. This step also splits the analytical dataset into a 70-30 train-test random sample.

 <br/>
 <img src="../Images/sqlr16.png" width="75%"> 
 

 The Analytical dataset is ready. We can start building the models now.


<h2>Model Development</h2>

17.	Open `step5(a)_model_train_rf.sql` and click on `Execute`.

 In this step the random forest model is trained on the training dataset.
 <br/>
 <img src="../Images/sqlr17.png" width="75%"> 


18.	Open `step5(b)_model_train_gbm.sql` and click on `Execute`.

 In this step the gradient boosting model is trained on the training dataset.
 <br/>
 <img src="../Images/sqlr18.png" width="75%">

 The model algorithms have been created. Now, we need to compute the model statistics.

19.	Open `step6_models_comparision.sql` and click on `Execute`.

 This step calculates model statistics like Accuracy and AUC on the test dataset for both the model algorithms.
 <br/>
 <img src="../Images/sqlr19.png" width="75%"> 

 The next step is to select the champion model using the model statistics and score the analytical dataset using the champion model.

20.	Open `step7(a)_scoring_leads.sql` and click on `Execute`.

 This step selects the champion model based on the AUC. It also scores the analytical dataset on the champion model.
 <br/>
 <img src="../Images/sqlr20.png" width="75%">

 Now that the champion model has been scored, we need to create the final dataset which will be used as the input for the dashboard.

21.	Open step7(b)_lead_scored_dataset.sql and click on `Execute`.
 <br/>
 <img src="../Images/sqlr21.png" width="75%">




22.	Once the PowerShell scripts have run, log into the SQL Server to view all the datasets that have been created in the `CampaignManagement` database.  Hit `Refresh` if necessary.
 <br/>
 <img src="../Images/alltables.png" width="30%">

 Right click on `dbo.lead_scored_dataset` and select `View Top 1000 Rows` to preview the scored data.
 
<h2>Visualizing Results </h2>
Now proceed to <a href="Visualize_Results.md">Visualizing Results with PowerBI</a>.