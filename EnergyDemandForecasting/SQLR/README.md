# Energy Demand Forecast Template with SQL Server 2016 R Services
* **Introduction**
  * **System Requirements**
  * **Workflow Automation**
* **Deployment Instructions**
  * **Step 1: Data Generation**
  * **Step 2: Preprocessing and Feature Engineering**
  * **Step 3: Train and Persist Model**
  * **Step 4: Score Model**
* **Visualization**
* **Cleanup**

##INTRODUCTION
This template demonstrates how to use [SQL Server R Services](https://msdn.microsoft.com/en-us/library/mt674876.aspx) to build an end-to-end, on-prem solution for electricity demand forecasting. For a cloud-based solution using Cortana Analytics Suite(CAS), please see [CAS Solution Template: Demand Forecasting for Energy](https://gallery.cortanaanalytics.com/SolutionTemplate/Demand-Forecasting-for-Energy-1).The solution template includes a real time data simulator, feature engineering, model retraining, forecasting, and visualization.
###SYSTEM REQUIREMENTS
* **SQL Server 2016 with R Services.**
You need SQL Server 2016 RC1 or later to deploy this template. SQL Server 2016 RC2 or later is recommended as the installation process is significantly simplified compared to earlier versions. If you don’t have access to any SQL Server, you have the following options:
  * Install SQL Server 2016 on you own computer or server. You can use both Windows and SQL Server Authentication in this case. Windows Authentication is recommended as no additional firewall configuration is needed.
  * Follow instructions [here](https://azure.microsoft.com/en-us/documentation/articles/virtual-machines-provision-sql-server/)  to provision a SQL server virtual machine in Azure. You will need an Azure subscription to do this. You can only use SQL Server Authentication to access a remote server.  
 
  If you are using SQL Server 2016 RC2, follow the post installation instructions [here](https://msdn.microsoft.com/en-us/library/mt696069.aspx) to set up SQL Server R Services. 

* **Login requirements.**
The login you use to access the SQL Server and database needs to have the following permissions. **NOTE**: If the login is a member of the **sysadmin** server role, it has met all the requirements. You can check this in the “Security” section of the server using SQL Server Management Studio or Visual Studio.
  * Permission to create database. The login needs to be a member of the **dbcreator** server role to create new database. 
  * Permissions to read data and run R scripts in the database. If you followed the post-installation configuration steps when setting up R Services, your login should already have these permissions. 
  * Access to SQL Server Agent. SQL Server Agent is used to schedule jobs in this template. Members of the **SQLAgentUserRole**, **SQLAgentReaderRole**, and **SQLAgentOperatorRole** fixed database roles in msdb, and members of the **sysadmin** fixed server role have access to SQL Server Agent. A user that does not belong to any of these roles cannot use SQL Server Agent. For more information on the roles used by SQL Server Agent, see [Implement SQL Server Agent Security](https://msdn.microsoft.com/en-us/library/ms190926.aspx). 
* **Local client requirements.**
On the computer where you will run the deployment script, you need the following programs installed:
  * Windows PowerShell. Windows PowerShell can be downloaded from [here](https://www.microsoft.com/en-us/download/details.aspx?id=42554). 
  * SQL Command Line Utilities. If you have SQL Server Management Studio installed, you already have SQL Command Line Utilities. Otherwise, it can be downloaded from [here](https://www.microsoft.com/en-us/download/details.aspx?id=36433). 
  * PowerBI Desktop. PowerBI Desktop can be downloaded from [here](https://powerbi.microsoft.com/en-us/desktop/)

###WORKFLOW AUTOMATION
The PowerShell script *setup.ps1* is used to deploy the template. Follow the deployment instructions below or the file *TemplateDeploymentInstructions.pdf* to deploy the template. The deployment process takes about 30 minutes if you meet all the system requirements before deployment.

Briefly, the PowerShell script will first ask for which server and database you want to deploy the template and what is the login credential to access the server and database. Then the script will call the SQL files in this template to bulk load data to the specified database, create tables, stored procedures, and SQL Server Agent jobs used in the template. The jobs are scheduled to run every hour/15 minutes to generate simulated data, retrain the model and generate new forecasting. The figure below shows the end-to-end workflow
![fig_pbidashboard][10]
The following jobs will be created on your server:

Job name | Description | Frequency
-------- | ----------- | ---------
\[database name\]_Energy_Demand_data_simulator | Generate simulated demand data |Every 15 minutes
\[database name\]_Energy_Temperature_data_simulator |	Generate simulated temperature data	|Every hour
\[database name\]_prediction_job_101 | Retrain and forecast for region 101 |Every 15 minutes
\[database name\]_prediction_job_102 | Retrain and forecast for region 102 |Every 15 minutes
\[database name\]_prediction_job_103 | Retrain and forecast for region 103 |Every 15 minutes
\[database name\]_prediction_job_104 | Retrain and forecast for region 104 |Every 15 minutes
**NOTE**: If you are using Windows Authentication, only the data simulators and prediction job for region 101 will be created, as we assumed a less powerful server is used  

The stored procedure usp_delete_job can be used to delete the scheduled jobs if you are done with testing the template.

Tables and stored procedures created will be explained separately in details in each step they are used. 
##Deployment Instructions
We recommend using an empty database to deploy this template, otherwise the same tables and other same database objects in this template will be wiped off. You don’t have to create a database first. The deployment script will create one if no database matches the database name you entered in the deployment process.
 * Open Windows Powershell and navigate to the “SQLR” directory using the following command:  
   **cd [directory]**  
   **NOTE: Make sure there is NO dash in your file directory.**   
 * Run the following command to start the deployment process:  
   **.\setup.ps1**  
   If you are using Windows Authentication, you will be asked for the server name and database name. If you are using SQL Server Authentication, you will be asked for the server name, database name, login user name, and password. Include the port number in the server name when applicable, e.g. testserver, 1433. The deployment will take a few minutes. 
 * Verify new forecast is generated in the database (OPTIONAL)  
   The training and forecasting runs every 15 minutes and retraining and forecasting takes a few minutes. You should see forecasting results populated to the DemandForecast table in your database within 20~30 minutes after deployment.   
You can use the following command to check forecasting data. (User name and password are not needed for Windows Authentication.)  
**Sqlcmd -S [server name] -U [user name] -P [password] -Q "Use [database name]; SELECT TOP 10 * from DemandForecast;"**  
For example:  
**Sqlcmd -S testerver -U username -P password -Q "Use testdb; SELECT TOP 10 * from DemandForecast;"**  
You can also use Visual Studio or SQL Server Management Studio to examine the tables, stored procedures, and scheduled jobs in more details. 

**Details of each step of the forecasting process are explained below.** 
###STEP 1: DATA GENERATION
* The PowerShell script first uses bcp to bulk load DemandHistory15Minutes.txt into table DemandSeed and TemperatureHistoryHourly.txt into table TemperatureSeed. 
* The stored procedure usp_GenerateHistoricalData then loads the seed data into tables DemandReal and TemperatureReal as historical data. 
* The stored procedure usp_Data_Simulator_Demand is invoked every 15 minutes and usp_Data_Simulator_Temperature is invoked every hour to generate on-going data which are also saved into DemandReal and TemperatureReal.

**Input files**:  
  DemandHistory15Minutes.txt  
  TemperatureHistoryHourly.txt  
**Stored procedures**:

Procedure name |Description
---------------|-----------
usp_GenerateHistoricalData|Generate historical data by loading data from table DemandSeed to table DemandReal and from table TemperatureSeed table to table TemperatureReal. 
usp_Data_Simulator_Demand|Generate simulated demand data
usp_Data_Simulator_Temperature|Generate simulated temperature data

**Output tables**:

Table name|Description
----------|------------
DemandSeed|Seed data for generating simulated demand data in DemandReal
TemperatureSeed|Seed data for generating simulated temperature data in TemperatureReal
DemandReal|Simulated demand data, including one year of historical data and newly generated on-going data after template deployment
TemperatureReal|Simulated temperature data, including one year of historical data and newly generated forecasted temperature data for the next 6 hours. 

###STEP 2: PREPROCESSING AND FEATURE ENGINEERING
The stored procedure usp_featureEngineering fills NA values in the historical data and computes features including month of year, hour of day, weekday/weekend, linear trend, Fourier components, lag, etc. For a given region and time, it updates the table InputAllFeatures with the features computed from the latest demand data from DemandRealand temperature data from table TemperatureReal. 

**Input tables**:  
DemandReal  
TemperatureReal  
**Stored procedure**: usp_featureEngineering  
**Output table**:

Table name|Description
----------|-----------
InputAllFeatures|Features generated from historical demand data and temperature data for model training
###STEP 3: TRAIN AND PERSIST MODEL
The stored procedure usp_trainModel gets features from table InputAllFeatures and trains a Random Forest Regression model using the high performance analytics algorithm rxDForest in Microsoft R Server (MRS). The stored procedure usp_persistModel calls usp_trainModel and saves the trained model to table Model. 

**Input table**: InputAllFeatures  
**Stored procedures**:

Procedure name|Description
--------------|-----------
usp_trainModel|Train models
usp_persistModel|Call usp_trainModel and save the trained models

**Output table**:

Table name|Description
----------|-----------
Model|Models trained for different regions and time points
###STEP 4: SCORE MODEL
The stored procedure usp_predictDemand selects the trained model for a given region and time from table Model and generates forecasted demand for the next 6 hours with a 15-minutes interval. 

**Input tables**:  
InputAllFeatures  
Model  
**Stored procedures**:

Procedure name|Description
--------------|-----------
usp_predictDemand|Produce forecasted demand
usp_energyDemandForecastMain|Call usp_featureEngineering, usp_persistModel, usp_predictDemand for model retraining and forecasting

**Output table**:

Table name|Description
----------|-----------
DemandForecast|Forecasted demand for the next 6 hours with a 15 minutes interval
###Other tables and stored procedures

**Tables**

Table name|Description
----------|-----------
RegionLookup|Latitude and longitude of each region for generating PowerBI visualization
runlogs|Logs of job runs
stepLookup|Step lookup table for generating run logs
**Stored procedures**

Procedure name|Description
--------------|-----------
usp_create_job|Create SQL Server Agent jobs for data simulation and forecasting
usp_delete_job|Delete SQL Server Agent jobs

##VISUALIZATION
A PowerBI dashboard template is provided to visualize the simulated actual demand, forecasted demand and forecasting accuracy. Follow the following steps to produce your own dashboard.
 * Open the file “EnergyDemandForecast” in the “PowerBI” folder. The dashboard will be empty and contain some errors when you first open it. If it asked you to enter credentials to access the database used to create this template as shown below, click “cancel”.
![PowerBI dashboard open][1]
 * Click “Edit Queries” at the top of the user interface.
<img src=https://github.com/Microsoft/SQL-Server-R-Services-Samples/blob/master/EnergyDemandForecasting/SQLR/fig_pbieditqueries.png alt="fig_pbieditqueries" width=500 height=125>
 * Click “Source” on the right side of the user interface and enter your own server and database name in the prompt window.  
<img src=https://github.com/Microsoft/SQL-Server-R-Services-Samples/blob/master/EnergyDemandForecasting/SQLR/fig_pbieditsource.png alt="fig_pbieditsource" width=400 height=350>
<img src=https://github.com/Microsoft/SQL-Server-R-Services-Samples/blob/master/EnergyDemandForecasting/SQLR/fig_pbieditsource2.png alt="fig_pbieditsource2" width=400 height=325>
 * Enter user name and password for accessing the database  
For Windows Authentication, select “Windows” on the left side of the prompt window as shown below.   
![fig_pbiwindowsauth][5]  
For SQL Server Authentication, select “Database” on the left side of the prompt window as shown below.   
![fig_pbisqlauth][6]  
If you encounter the following prompt, click OK to continue.  
![fig_pbiencryption][7]  
 * Apply changes.   
![fig_pbiapplychanges][8]  

You should see a PowerBI dashboard looks like the figure below. At first, you only see the actual load data in yellow. The first set of forecasted demand will be produced within 20~30minutes. Refresh the dashboard to see the latest data. **NOTE**: If you are using Windows Authentication, you will only see one region on the dashboard, as we assumed a less powerful server is used and only created a job for one region.   
![fig_pbidashboard][9]   
[1]:fig_pbiopen.png
[2]:fig_pbieditqueries.png
[3]:fig_pbieditsource.png
[4]:fig_pbieditsource2.png
[5]:fig_pbiwindowsauth.png
[6]:fig_pbisqlauth.png
[7]:fig_pbiencryption.png
[8]:fig_pbiapplychanges.png
[9]:fig_pbidashboard.png
[10]:fig_workflow.png
##Cleanup
If you are done with testing the template and want to delete the scheduled jobs, run the following PowerShell command.  
**Sqlcmd -S [server name] -U [user name] -P [password] -Q "Use [database name]; EXEC usp_delete_job @dbname = '[database name]';"**  
For example:  
**Sqlcmd -S testerver -U username -P password -Q "Use testdb; EXEC usp_delete_job @dbname = 'testdb';"**  
 
**NOTE**: this only delete the scheduled SQL Server Agent jobs. The database and tables will NOT be deleted by this command.


