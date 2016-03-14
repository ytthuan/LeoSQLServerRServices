#Online Fraud Detection Template with SQL Server 2016 R Services

In this template, we demonstrate how to develop and deploy end-to-end Fraud Detection solutions with [SQL Server 2016 R Services](https://msdn.microsoft.com/en-us/library/mt674876.aspx). 

In this template, the online purchase transaction fraud detection scenario (for the online merchants, detecting whether a transaction is made by the original owner of payment instrument) is used as an example. We solve the Fraud Detection as a **binary classification** problem.

The solutions are demonstrated using a Online Transaction data, with the following files:
<table style="width:85%">
  <tr>
    <th>File</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>.\Data\Online Fraud-Fraud Transactions.csv</td>
    <td>Raw fraud transaction data</td>
  </tr>
  <tr>
    <td>.\Data\Online Fraud-Untagged Transactions.csv</td>
    <td>Raw transaction data without fraud tag</td>
  </tr>
</table>

For a full description of the template, please refer to the [template](https://gallery.cortanaanalytics.com/Experiment/Online-Fraud-Detection-Step-1-of-5-Generate-tagged-data-2) in Cortana Analytics gallery.

In this template with SQL Server R Services, we show two version of implementation:
 
- **Model Development with Microsoft R Server in R IDE**. Run the code in R IDE (e.g., RStudio, R Tools for Visual Studio) with data in SQL Server, and execute the computation in SQL Server.

- **Model Operationalization In SQL**. Deploy the modeling steps to SQL Stored Procedures, which can be run within SQL environment (such as SQL Server Management Studio) or called by applications to make predictions. A powershell script is provided to run the steps end-to-end. 

The following is the directory structure for this template:

* **Data**    This contains the provided sample data.
* **R**	    This contains the R development code (Microsoft R Server). It runs in R IDE, with computation being done in-database (by setting compute context to SQL Server). 
* **SQLR**    This contains the Stored SQL procedures from data processing to model deployment. It runs in SQL environment. A Powershell script is provided to invoke the modeling steps end-to-end.  See Readme files in each directory for detailed instructions.
