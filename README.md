#Machine Learning Templates with SQL Server 2016 R Services

In these examples, we demonstrate how to develop and deploy end-to-end advanced analytics solutions with [SQL Server 2016 R Services](https://msdn.microsoft.com/en-us/library/mt674876.aspx). 

**Develop models in R IDE**. SQL Server 2016 R services allows Data Scientists to develop solutions in an R IDE (such as RStudio, Visual Studio R Tools) with Open Source R or Microsoft R Server, using data residing in SQL Server, and computing done in-database. 

**Operationalize models in SQL**. Once the model development is completed, the model (data processing, feature engineering, training, saved models, and production scoring) can be deployed to SQL Server using T-SQL Stored Procedures, which can be run within SQL environment (such as SQL Server Management Studio) or called by applications to make predictions. 

**Machine Learning Templates.** We have developed a number of templates for solving specific machine learning problems with SQL Server R Services. These templates provides a higher starting point and aims to enable users to quickly build and deploy solutions. Each template includes the following components:

- Predefined *data schema* applicable to the specific domain
- Domain specific *data processing* and *feature engineering* steps
- Preselected *training *algorithms fit to the specific domain 
- Domain specific *evaluation metrics* where applicable
- *Prediction (scoring)* in production.  

The available templates are listed below. Please check back often, as there will be new templates added periodically. 

- Predictive Maintenance.  Predict machine failures.
- Customer Churn.   Predict when a customer churn happens.
- Online Purchase Fraud Detection. Predict if an online purchase transactions is fraudulent. 

<!--
- Retail Forecasting. Forecast the product sales for a retail store.
-->



**Templates with SQL Server R Services**. In these templates, we show the two version of implementations:
 
- Development Code in R IDE 
- Operationalization In SQL

The following is the directory structure for each template:

* **Data**    This contains the provided sample data for each application.
* **R**	      This contains the R development code (Microsoft R Server). It runs in R IDE, with computation being done in-database (by setting compute context to SQL Server). 
* **SQLR**    This contains the Stored SQL procedures from data processing to model deployment. It runs in SQL environment. A Powershell script is provided to invoke the modeling steps end-to-end. 


 

