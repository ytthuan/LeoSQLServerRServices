# Predictive Maintenance Template with SQL Server ML Services

In this template, we demonstrate how to develop and deploy end-to-end Predictive Maintenance solutions with [SQL Server ML Services](https://docs.microsoft.com/en-us/sql/advanced-analytics/what-is-sql-server-machine-learning). Predict machine failures before they happen, to minimize down time, reduce costs and increase productivity. This is an important scenario for manufacturing. This template is comparable to the other [Predictive Maintenance template](https://github.com/Microsoft/SQL-Server-R-Services-Samples/blob/master/PredictiveMaintenanceModelingGuide). The problem is approached differently.

In this template, we solve the following three problems:

- Predict the Remaining Useful Life (RUL) of an asset, or Time to Failure (TTF). This is formulated as a **regression** problem.  
- Predict if an asset will fail within certain time frame (e.g. days). This is formulated as a **binary classification** problem. 
- Predict if an asset will fail in different time windows. This is formulated as a **Multi-class classification** problem. 

The solutions are demonstrated using an aircraft engine data, with the following files:
<table style="width:85%">
  <tr>
    <th>File</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>.\Data\PM_train.csv</td>
    <td>Raw training data, aircraft engine run-to-failure data</td>
  </tr>
  <tr>
    <td>.\Data\PM_test.csv</td>
    <td>Raw testing data, aircraft engine operating data without failure events recorded</td>
  </tr>
<tr>
    <td>.\Data\PM_truth.csv</td>
    <td>Ground truth data, containing the information for each engine in testing data</td>
  </tr>  
<tr>
    <td>.\Data\PM_Score.csv</td>
    <td>Data sampled from test data for scoring (predictions) </td>
  </tr>
</table>

In this template with SQL Server ML Services, we show two version of implementation:
 
- **Model Development with Microsoft ML Server in R IDE**. Run the code in R IDE (e.g., RStudio, R Tools for Visual Studio) with data in SQL Server, and execute the computation in SQL Server.

- **Model Operationalization In SQL**. Deploy the modeling steps to SQL Stored Procedures, which can be run within SQL environment (such as SQL Server Management Studio) or called by applications to make predictions. A powershell script is provided to run the steps end-to-end. 

The following is the directory structure for this template:

* **Data**    This contains the provided sample data.
* **R**	      This contains the R development code (Microsoft ML Server). It runs in R IDE, with computation being done in-database (by setting compute context to SQL Server). 
* **SQLR**    This contains the Stored SQL procedures from data processing to model deployment. It runs in SQL environment. A Powershell script is provided to invoke the modeling steps end-to-end.  See Readme files in each directory for detailed instructions.

 
