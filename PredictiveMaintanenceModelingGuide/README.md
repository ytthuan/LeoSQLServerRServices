#SQL R Services: Predictive Maintenance Modeling Guide
In this template, we demonstrate how to develop a Predictive Maintenance solution with SQL Server 2016 R Services where the process is aligned with the existing R Notebook published in the [Cortana Intelligence Gallery](https://gallery.cortanaintelligence.com/Notebook/Predictive-Maintenance-Modelling-Guide-R-Notebook-1) but works with a larger dataset. 

##In this template:
* There are 5 data sources namely: telemetry, errors, maintenance, machines, failures

* Data ingestion, feature engineering and data preparation is done using SQL code

* Data visualization and multi-class classification model is done via R code running on SQL Server

##Implementation prerequisites: 
* SQL Server 2016 with R Services: https://msdn.microsoft.com/en-us/library/mt696069.aspx 

* R IDE such as R Studio or R Tools for Visual Studio to access the data from the server: https://msdn.microsoft.com/en-us/microsoft-r/install-r-client-windows 

* Git Large File Storage: this is needed to download the large CSV files from Github: https://github.com/github/git-lfs, https://github.com/github/git-lfs/wiki/Installation

###The directory structure for this template is as follows:
* Data: Sample CSV files for telemetry, errors, maintenence, machines, failures can be accessed via the Data folder or through Azure Blob. 
	- telemetry: https://pdmmodelingguide.blob.core.windows.net/pdmdata/telemetry.csv 
	- errors: https://pdmmodelingguide.blob.core.windows.net/pdmdata/errors.csv
	- maintenence:https://pdmmodelingguide.blob.core.windows.net/pdmdata/maint.csv 
	- machines: https://pdmmodelingguide.blob.core.windows.net/pdmdata/machines.csv 
	- failures: https://pdmmodelingguide.blob.core.windows.net/pdmdata/failures.csv
* Codes: 

	- SQL code used for data ingestion and feature engineering: 	
		- pdm_data_ingestion.sql
		- pdm_feature_engineering.sql
	- R code for data visualization: 
		- pdm_visualization.R
	- R code that runs on the SQL Server to build the models: 
		- pdm_modeling.R 

##Implementation setup overview: 

![1]

##Input data overview: 
* Telemetry.csv: The telemetry time-series data consists of voltage, rotation, pressure and vibration measurements.

* Errors.csv: The error logs contain non-breaking errors thrown while the machine is still operational and do not qualify as failures. The error date and times are rounded to the closest hour since the telemetry data is collected at an hourly rate.

* Maint.csv: The scheduled and unscheduled maintenance records which correspond to both regular inspection of components as well as failures. A record is generated if a component is replaced during the scheduled inspection or replaced due to a break down. 

* Machines.csv: This data set includes machine model and age in years in service.

* Failures.csv: These are the records of component replacements due to failures. Each record has a date and time, machine ID and failed component type associated with it.

##Feature engineering overview:
The first step in predictive maintenance applications is feature engineering which combines the different data sources to create features that best describe a machines’ health condition at a given point in time. 

* Lag Features from Telemetry: Telemetry data almost always comes with time-stamps which makes it suitable for calculating lagging features. In the following template, rolling mean and standard deviation of the telemetry data over the last 3-hour lag window is calculated for every 3 hours.

* Lag Features from Errors: Similar to telemetry, errors also come with time-stamps. However, unlike telemetry that had numerical values, errors have categorical values denoting the type of error that occurred at a time-stamp. In this case, aggregating methods such as averaging does not apply. Hence, counting the different categories is a more viable approach where lagging counts of different types of errors that occurred in the lag window are calculated. 

* Days Since Last Replacement from Maintenance: This data contains the information of component replacement records. A relevant feature from this data set is to calculate how long it has been since a component was last replaced.

* Machine Features: The machine features are used directly since they hold descriptive information about the type of the machines and their age which is defined as the years in service.

##Label Construction:
The prediction problem for this example scenario is to compute the probability that a machine will fail in the next 24 hours due to a certain component failure (component 1,2,3 or 4). The rest of the records are labeled as "none" indicating there is no failure within the next 24 hours.

##Modeling: Training, Validation and Evaluation
For predictive maintenance problems, a time-dependent splitting strategy is used to estimate performance which is done by validating and testing on examples that are later in time than the training examples. For a time-dependent split, a point in time is picked and model is trained on examples up to that point in time, and validated on the examples after that point assuming that the future data after the splitting point is not known. 

##Implementation process: 
* Create your SQL Server, then enable [R services](https://msdn.microsoft.com/en-us/library/mt696069.aspx).

* Install any R IDE with [Microsoft R client](https://msdn.microsoft.com/en-us/microsoft-r/install-r-client-windows). Ensure to check your R code can access your SQL Server DB with the credentials.   

* In the SQL Server, create a database where you would like to load the datasets and perform feature engineering. Then run the SQL scripts in this order: 

	- pdm_data_ingestion.sql (edit the folder path to where you have saved the CSV files)
	- pdm_feature_engineering.sql

* In your R IDE, run the following scripts: 
	- pdm_visualization.R, 
	- pdm_modeling.R 
	
	Ensure that you edit the code with your SQL Server credentials in both the R scripts. 

* The final dataset is loaded onto SQL Server with the evaluation metrics: metrics_df.

## Operationalization (next steps):
The SQL/R codes can be converted to Stored SQL procedures which can run in the SQL environment. Then a PowerShell script can be used to invoke the modeling steps end-to-end.


[1]: ./Images/Pdm_Readme_github_img1.PNG




