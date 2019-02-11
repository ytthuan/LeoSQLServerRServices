# Customer Churn Prediction Template with SQL Server ML Services
Understanding which customers run the risk of churning it paramount in many industries, including retail and finance.
Being able to predict when a customer is likely to churn helps retain them, by for example allowing for tailored interaction with the customer.
In this template, we demonstrate how to develop and deploy end-to-end customer churn prediction models with [SQL Server ML Services](https://docs.microsoft.com/en-us/sql/advanced-analytics/what-is-sql-server-machine-learning). 

This template demonstrates customer churn modeling in a retail store scenario, using customer demographic data and shopping activity data:
<table style="width:85%">
  <tr>
    <th>File</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>.\Data\Users.csv</td>
    <td>Customer demographic data</td>
  </tr>
  <tr>
    <td>.\Data\Activities.csv</td>
    <td>User shopping activity data</td>
  </tr>
</table>

This templates demonstrate how to use SQL stored procedures to do model development and operationalization. The data processing and feature engineering steps are implemented using pure SQL, while the model training, evaluation, and prediction scoring are done using SQL procedures calling R (Microsoft ML Server) code, the capability provided by SQL Server ML Services. These procedures can be run within SQL environment (such as SQL Server Management Studio) or called by applications to make predictions. A powershell script is provided to run the steps end-to-end. 

The following is the directory structure for this template:

* **Data**    This contains the provided sample data.
* **SQLR**    This contains the Stored SQL procedures from data processing to model deployment. It runs in SQL environment. A Powershell script is provided to invoke the modeling steps end-to-end.  See Readme files in each directory for detailed instructions.

### Deploy to Azure on SQL Server
[![Deploy to Azure (SQL Server)](https://raw.githubusercontent.com/Azure/Azure-CortanaIntelligence-SolutionAuthoringWorkspace/master/docs/images/DeployToAzure.PNG)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FMicrosoft%2FSQL-Server-R-Services-Samples%2Ftree%2F/master%2FChurn%2F/ArmTemplates%2Fcampaign_arm.json)
