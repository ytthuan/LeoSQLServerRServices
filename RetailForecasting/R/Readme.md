This is the R (Microsoft R Server) code for Retail Forecasting template using SQL Server R Services. 

Two modeling solutions are provided for this template :

* **Time Series Forecasting:** 
	* Seasonal Trend Decomposition using Loess (STL) + Exponential Smoothing (ETS);
	* Seasonal Naive;
	* Seasonal Trend Decomposition using Loess + AutoRegressive Integrated Moving Average (ARIMA).
* **Regression Models:** 
	* Boosted Decision Tree Regression
	* Random Forest Regression 

It consists of the following files:

<table style="width:85%">
  <tr>
    <th>File</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>01-data-preprocess.R</td>
    <td>Load data to SQL tables, apply business rules to the data, filling NAs, etc</td>
  </tr>
  <tr>
    <td>02-time-series-modeling</td>
    <td>Train the time series models</td>
  </tr>
  <tr>
    <td>03-feature-engineering</td>
    <td>Feature engineering for regression models</td>
  </tr>
  <tr>
    <td>04-regression-modeling</td>
    <td>Train the regression models></td>
  </tr>
  <tr>
    <td>05-evaluate-models</td>
    <td>Evaluate the regression models</td>
  </tr>
</table> 

A detailed description of the template, implemented in Azure Machine Learning Studio can be found [here](https://gallery.cortanaintelligence.com/Experiment/Retail-Forecasting-Step-1-of-6-data-preprocessing-5).