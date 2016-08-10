# Campaign Management Template with R Scripts

This is the R (Microsoft R Server) code for Campaign Management template using SQL Server R Services. This code runs on a local R IDE (such as RStudio, R Tools for Visual Studio), and the computation is done in SQL Server (by setting compute context).

This is primarily for customers who prefer advanced analytical solutions on a local R IDE

It consists of the following files:

| File | Description |
| --- | --- |
| Step1\_input\_data.R | Simulates the 4 input datasets |
| Step2\_data\_preprocessing.R | Performs preprocessing steps like outlier treatment and missing value treatment on the input datasets |
| Step3\_feature\_engineering\_AD\_creation.R | Performs Feature Engineering and creates the Analytical Dataset |
| Step4\_model\_rf\_gbm.R | Builds the Random Forest &amp; Gradient Boosting models, identifies the champion model and scores the Analytical dataset |

Note: The connection parameters are not set in any of the scripts. The user will have to enter these parameters in the beginning of each script before running them.
