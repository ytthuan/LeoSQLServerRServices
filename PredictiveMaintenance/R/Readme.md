# Predictive Maintenance
This is the R (Microsoft ML Server) code for Predictive Maintenance template using SQL Server ML Services. 
Predictive maintenance encompasses a variety of topics, including but not limited to: failure prediction, failure diagnosis (root cause analysis), failure detection, failure type classification, and recommendation of mitigation or maintenance actions after failure. This predictive maintenance template focuses on the techniques used to predict when an in-service machine will fail, so that maintenance can be planned in advance.
The template solves the following problems:

- Predict the Remaining Useful Life (RUL) of an asset, or Time to Failure (TTF). This is formulated as a **regression** problem.  
- Predict if an asset will fail within certain time frame (e.g. days). This is formulated as a **binary classification** problem. 
- Predict if an asset will fail in different time windows. This is formulated as a **Multi-class classification** problem. 

It consists of the following files:

<table style="width:85%">
  <tr>
    <th>File</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>01-data-preparation.R</td>
    <td>Load data to SQL tables, data labeling, feature engineering, normalization</td>
  </tr>
  <tr>
    <td>02a-regression-modeling</td>
    <td>Train and evaluate multiple regression models</td>
  </tr>
  <tr>
    <td>02b-binary-classification-modeling</td>
    <td>Train and evaluate multiple binary classfication models</td>
  </tr>
  <tr>
    <td>02b-binary-classification-modeling</td>
    <td>Train and evaluate multiple multiclass classfication models</td>
  </tr>
</table> 