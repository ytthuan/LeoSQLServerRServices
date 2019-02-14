# Energy Demand Forecast Template with SQL Server ML Services
Accurately forecasting spikes in demand for products and services can give a company a competitive advantage. The better the forecasting, the more they can scale as demand increases, and the less they risk holding onto unneeded inventory. Use cases include predicting demand for a product in a retail/online store, forecasting hospital visits, and anticipating power consumption.

This solution template focuses on demand forecasting within the energy sector. Storing energy is not cost-effective, so utilities and power generators need to forecast future power consumption so that they can efficiently balance the supply with the demand. During peak hours, short supply can result in power outages. Conversely, too much supply can result in waste of resources. Advanced demand forecasting techniques detail hourly demand and peak hours for a particular day, allowing an energy provider to optimize the power generation process. 

### Deploy to Azure on SQL Server
[![Deploy to Azure (SQL Server)](https://raw.githubusercontent.com/Azure/Azure-CortanaIntelligence-SolutionAuthoringWorkspace/master/docs/images/DeployToAzure.PNG)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FMicrosoft%2FSQL-Server-R-Services-Samples%2Fmaster%2FEnergyDemandForecasting%2FArmTemplates%2Fenergydemandforecasting_arm.json)


This template demonstrates how to use [SQL Server ML Services](https://docs.microsoft.com/en-us/sql/advanced-analytics/what-is-sql-server-machine-learning) to build an end-to-end, on-prem solution for electricity demand forecasting. The solution template includes a real time data simulator, feature engineering, model retraining, forecasting, and visualization.  
In this template with SQL Server ML Services, we show two versions of implementation:
 
- **Model Development with Microsoft ML Server in R IDE**. Run the code in R IDE (e.g., RStudio, R Tools for Visual Studio) with data in SQL Server, and execute the computation in SQL Server.

- **Model Operationalization In SQL**. Deploy the modeling steps to SQL Stored Procedures, which can be run within SQL environment (such as SQL Server Management Studio) or called by applications to make predictions. A powershell script is provided to deploy the template automatically.
**You can also deploy the solution to Azure on SQL Server using the `Deploy to Azure` button above.**

Below is the directory structure for this template:

* **SQLR**:    SQL stored procedures for data simulation, data preprocessing, feature engineering, model training and scoring. The stored procedures are run on a SQL server.
* **Data**:    Sample data for running R scripts.
* **R**:	      R development code (Microsoft ML Server). It runs in R IDE, with computation being done in-database (by setting compute context to SQL Server).  

See Readme files in each directory for detailed instructions.

**NOTE:** Please don't use "Download ZIP" to get this repository, as it will change the line endings in the data file. Use "git clone" to get a local copy of this repository. 

See [SQLR Folder](SQLR) for more info about the solution files, scripts, data structure and the tables created.