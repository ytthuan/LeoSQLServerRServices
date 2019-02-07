# Machine Learning Templates with SQL Server ML Services

> Discover more examples at [Microsoft Machine Learning Server](https://github.com/Microsoft/ML-Server)

In these examples, we will demonstrate how to develop and deploy end-to-end advanced analytics solutions with [SQL Server  ML Services](https://docs.microsoft.com/en-us/sql/advanced-analytics/what-is-sql-server-machine-learning). The samples provided here are created in R.
Samples in Python are available in [the ML Server Python Samples repository](https://github.com/Microsoft/ML-Server-Python-Samples).

## About SQL Server ML Services

**Develop models in R IDE**. SQL Server ML services allows Data Scientists to develop solutions in an R IDE (such as RStudio, Visual Studio R Tools) with Open Source R / Python or Microsoft ML Server, using data residing in SQL Server, and computing done in-database. 

**Operationalize models in SQL**. Once the model development is completed, the model (data processing, feature engineering, training, saved models, and production scoring) can be deployed to SQL Server using T-SQL Stored Procedures, which can be run within SQL environment (such as SQL Server Management Studio) or called by applications to make predictions. 

## Available Templates

### Machine Learning Templates
We have developed a number of templates for solving specific machine learning problems with SQL Server ML Services. These templates provides a higher starting point and aims to enable users to quickly build and deploy solutions. Each template includes the following components:

- Predefined *data schema* applicable to the specific domain
- Domain specific *data processing* and *feature engineering* steps
- Preselected *training *algorithms fit to the specific domain 
- Domain specific *evaluation metrics* where applicable
- *Prediction (scoring)* in production.  

The available templates are listed below.



| Template | Description |
| -------- | -------- |
|[Campaign Optimization](https://github.com/Microsoft/r-server-campaign-optimization)|Predict when and how to contact potential customers.|
|[Customer Churn](Churn)|Being able to predict when a customer is likely to churn helps retain them.|
|[Energy Demand Forecasting](EnergyDemandForecasting)|Forecast electricity demands for multiple regions.|
|[Fraud Detection](https://github.com/Microsoft/r-server-fraud-detection) |Predict if an online purchase transaction is fraudulent.|
|[Galaxy Classification](Galaxies)|This template shows how to use deep learning and image data to classify galaxies.|
|[Length of Stay](https://github.com/Microsoft/r-server-hospital-length-of-stay)|Predicting patients length of stay.|
|[Loan Chargeoff Prediction](https://github.com/Microsoft/r-server-loan-chargeoff)|Predicting probability of loans getting charged off.|
|[Loan Credit Risk](https://github.com/Microsoft/r-server-loan-credit-risk)|Predict risk of customers defaulting on loans.|
|[Predictive Maintenance (1)](PredictiveMaintenance)|Predict machine failures before they happen, to minimize down time, reduce costs and increase productivity. This template is comparable to the other Predictive Maintenance template. The problem is approached differently.|
|[Predictive Maintenance (2)](PredictiveMaintenanceModelingGuide)|Predicting machine failures before they happen. This template is comparable to the other Predictive Maintenance template. The problem is approached differently.|
|[Product Cross Sell](ProductCrossSell)|Demonstrates how to develop and deploy end-to-end customer cross-sell prediction models.|
|[Resume Matching](SQLOptimizationTips)|This template focuses on optimizing the performance of machine learning solutions integrated with SQL Server by demonstrating how we can find the best candidates for a job opening among millions of resumes within a few seconds.| 
|[Retail Forecasting](RetailForecasting)|Predicting the product sales for a retail store helps reduce warehousing cost and save time.|
|[Text Classification](https://github.com/Microsoft/ml-server-text-classification)|Classify text (such as news messages) into groups by subject.|

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

