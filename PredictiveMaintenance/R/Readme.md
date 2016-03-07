This is the R (Microsoft R Server) code for Predictive Maintenance template using SQL Server R Services. 

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
    <td>Train and evaluate multiple binary classfication models /td>
  </tr>
  <tr>
    <td>02b-binary-classification-modeling</td>
    <td>Train and evaluate multiple multiclass classfication models /td>
  </tr>
</table> 

A detailed description of the template, implemented in Azure Machine Learning Studio can be found [here](https://gallery.cortanaanalytics.com/Collection/Predictive-Maintenance-Template-3).