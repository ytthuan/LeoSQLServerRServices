# Retail Forecasting Template with SQL Server ML Services
Predicting the product sales for a retail store helps reduce warehousing cost and save time.
In this template, we demonstrate how to develop and deploy end-to-end Retail Forecasting solutions with [SQL Server ML Services](https://docs.microsoft.com/en-us/sql/advanced-analytics/what-is-sql-server-machine-learning). 

Accurate and timely forecast in retail business drives success. It is an essential enabler of supply and inventory planning, product pricing, promotion, and placement. This template will demonstrate how to build a retail forecasting solution with SQL and Microsoft ML services using the sales data from the retail industry. The sample data has been anonymized and transformed before being used in this sample. 

The input data schema is as following:

|Data Field|Description|
|-|-|
|ID1|Time series ID 1, ex. Store ID|
|ID2|Time series ID 2, ex. product / SKU ID|
|time|Observation time|
|value|Time series value, ex. Sales quantity|

**This template requires the `forecast` package**.

### Deploy to Azure on SQL Server
[![Deploy to Azure (SQL Server)](https://raw.githubusercontent.com/Azure/Azure-CortanaIntelligence-SolutionAuthoringWorkspace/master/docs/images/DeployToAzure.PNG)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FMicrosoft%2FSQL-Server-R-Services-Samples%2Fmaster%2FRetailForecasting%2FArmTemplates%2Fretailforecasting_arm.json%0A)

In this template with SQL Server ML Services, we show two version of implementation:
 
- **Model Development with Microsoft ML Server in R IDE**. Run the code in R IDE (e.g., RStudio, R Tools for Visual Studio) with data in SQL Server, and execute the computation in SQL Server.

- **Model Operationalization In SQL**. Deploy the modeling steps to SQL Stored Procedures, which can be run within SQL environment (such as SQL Server Management Studio) or called by applications to make predictions. A powershell script is provided to run the steps end-to-end. 

The following is the directory structure for this template:

* **Data**    This contains the provided sample data.
* **R**	      This contains the R development code (Microsoft ML Server). It runs in R IDE, with computation being done in-database (by setting compute context to SQL Server). 
* **SQLR**    This contains the Stored SQL procedures from data processing to model deployment. It runs in SQL environment. A Powershell script is provided to invoke the modeling steps end-to-end.  See Readme files in each directory for detailed instructions.
