# Machine Learning Templates with SQL Server ML Services

> Discover more examples at [Microsoft Machine Learning Server](https://github.com/Microsoft/ML-Server)

In these examples, we will demonstrate how to develop and deploy end-to-end advanced analytics solutions with [SQL Server  ML Services](https://docs.microsoft.com/en-us/sql/advanced-analytics/what-is-sql-server-machine-learning). The samples provided here are created in R.
Samples in Python are available in [the ML Server Python Samples repository](https://github.com/Microsoft/ML-Server-Python-Samples).

## About SQL Server ML Services

**Develop models in R IDE**. SQL Server ML services allows Data Scientists to develop solutions in an R IDE (such as RStudio, Visual Studio R Tools) with Open Source R / Python or Microsoft ML Server, using data residing in SQL Server, and computing done in-database. 

**Operationalize models in SQL**. Once the model development is completed, the model (data processing, feature engineering, training, saved models, and production scoring) can be deployed to SQL Server using T-SQL Stored Procedures, which can be run within SQL environment (such as SQL Server Management Studio) or called by applications to make predictions.

**Templates can be easily deployed to Azure using the `Deploy to Azure` button on the templates' readme pages.**

## Available Templates

### Machine Learning Templates
We have developed a number of templates for solving specific machine learning problems with SQL Server ML Services. These templates provides a higher starting point and aims to enable users to quickly build and deploy solutions. Each template includes the following components:

- Predefined *data schema* applicable to the specific domain
- Domain specific *data processing* and *feature engineering* steps
- Preselected *training *algorithms fit to the specific domain 
- Domain specific *evaluation metrics* where applicable
- *Prediction (scoring)* in production.  

The available templates are listed below.



| Template | Documentation |
| -------- | -------- |
|[Campaign Optimization](https://github.com/Microsoft/r-server-campaign-optimization)|[Website](https://microsoft.github.io/r-server-campaign-optimization/)|
|[Customer Churn](Churn)|[Repository](Churn)|
|[Energy Demand Forecasting](EnergyDemandForecasting)|[Repository](EnergyDemandForecasting)|
|[Fraud Detection](https://github.com/Microsoft/r-server-fraud-detection) |[Website](https://microsoft.github.io/r-server-fraud-detection/)|
|[Galaxy Classification](Galaxies)|[Repository](https://github.com/Microsoft/SQL-Server-R-Services-Samples/blob/master/Galaxies)|
|[Length of Stay](https://github.com/Microsoft/r-server-hospital-length-of-stay)|[Website](https://microsoft.github.io/r-server-hospital-length-of-stay/)|
|[Loan Chargeoff Prediction](https://github.com/Microsoft/r-server-loan-chargeoff)|[Website](https://microsoft.github.io//r-server-loan-chargeoff/)|
|[Loan Credit Risk](https://github.com/Microsoft/r-server-loan-credit-risk)|[Website](https://microsoft.github.io/r-server-loan-credit-risk/)|
|[Predictive Maintenance (1)](PredictiveMaintenance)|[Repository](PredictiveMaintenace)|
|[Predictive Maintenance (2)](PredictiveMaintenanceModelingGuide)|[Repository](PredictiveMaintenanceModelingGuide)|
|[Product Cross Sell](ProductCrossSell)|[Repository](ProductCrossSell)|
|[Resume Matching](SQLOptimizationTips-Resume-Matching)|[Repository](SQLOptimizationTips-Resume-Matching)|
|[Retail Forecasting](RetailForecasting)|[Repository](RetailForecasting)|
|[Text Classification](https://github.com/Microsoft/ml-server-text-classification)|[Website](https://microsoft.github.io/ml-server-text-classification/)|

### Templates with SQL Server ML Services
In these templates, we show the two version of implementations:
 
- Development Code in R IDE 
- Operationalization In SQL

The following is the directory structure for each template:

* **Data**    This contains the provided sample data for each application.
* **R**	      This contains the R development code (Microsoft ML Server). It runs in R IDE, with computation being done in-database (by setting compute context to SQL Server). 
* **SQLR**    This contains the Stored SQL procedures from data processing to model deployment. It runs in SQL environment. A Powershell script is provided to invoke the modeling steps end-to-end. 

### Other templates
| Template | Description |
| -------- | ----------- |
| [Performance Tuning](PerfTuning/README.md)| This template provides a few tips on how to improve performance of running R scripts in SQL Server compute context.|

**NOTE:** Please don't use "Download ZIP" to get this repository, as it will change the line endings in the data files. Use "git clone" to get a local copy of this repository. 

## Contributing
This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

