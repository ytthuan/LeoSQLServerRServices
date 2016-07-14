# Energy Demand Forecast Template with SQL Server 2016 R Services
Demand forecasting is an important problem in various domains including energy, retail, services, etc. Accurate demand forecasting helps companies conduct better production planning, resource allocation, and make other important business decisions. In the energy sector, demand forecasting is critical for reducing energy storage cost and balancing supply and demand.  
This template demonstrates how to use [SQL Server R Services](https://msdn.microsoft.com/en-us/library/mt674876.aspx) to build an end-to-end, on-prem solution for electricity demand forecasting. For a cloud-based solution using Cortana Analytics Suite(CAS), please see [CAS Solution Template: Demand Forecasting for Energy](https://gallery.cortanaanalytics.com/SolutionTemplate/Demand-Forecasting-for-Energy-1).The solution template includes a real time data simulator, feature engineering, model retraining, forecasting, and visualization.  
In this template with SQL Server R Services, we show two versions of implementation:
 
- **Model Development with Microsoft R Server in R IDE**. Run the code in R IDE (e.g., RStudio, R Tools for Visual Studio) with data in SQL Server, and execute the computation in SQL Server.

- **Model Operationalization In SQL**. Deploy the modeling steps to SQL Stored Procedures, which can be run within SQL environment (such as SQL Server Management Studio) or called by applications to make predictions. A powershell script is provided to deploy the template automatically.

Below is the directory structure for this template:

* **SQLR**:    SQL stored procedures for data simulation, data preprocessing, feature engineering, model training and scoring. The stored procedures are run on a SQL server.
* **Data**:    Sample data for running R scripts.
* **R**:	      R development code (Microsoft R Server). It runs in R IDE, with computation being done in-database (by setting compute context to SQL Server).  

See Readme files in each directory for detailed instructions.

**NOTE:** Please don't use "Download ZIP" to get this repository, as it will change the line endings in the data file. Use "git clone" to get a local copy of this repository. 

