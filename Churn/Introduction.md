#Customer Churn Prediction Template with SQL Server ML Services

In this template, we demonstrate how to develop and deploy end-to-end customer churn prediction models with [SQL Server ML Services]https://docs.microsoft.com/en-us/sql/advanced-analytics/what-is-sql-server-machine-learning). 

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

This template is the on-prem equivalent of the [template](https://gallery.cortanaanalytics.com/Collection/Predictive-Maintenance-Template-3) in Cortana Analytics gallery.

This templates demonstrate how to use SQL stored procedures to do model development and operationalization. The data processing and feature engineering steps are implemented using pure SQL, while the model training, evaluation, and prediction scoring are done using SQL procedures calling R (Microsoft R Server) code, the capability provided by SQL Server R Services. These procedures can be run within SQL environment (such as SQL Server Management Studio) or called by applications to make predictions. A powershell script is provided to run the steps end-to-end. 

The following is the directory structure for this template:

* **Data**    This contains the provided sample data.
* **SQLR**    This contains the Stored SQL procedures from data processing to model deployment. It runs in SQL environment. A Powershell script is provided to invoke the modeling steps end-to-end.  See Readme files in each directory for detailed instructions.

 
