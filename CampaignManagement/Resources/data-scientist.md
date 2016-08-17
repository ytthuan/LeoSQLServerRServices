<img src="Images/management.png" align="right">
# For the Data Scientist

SQL Server R Services brings the compute to the data by allowing R to run on the same computer as the database. It includes a database service that runs outside the SQL Server process and communicates securely with the R runtime. 

This solution packet shows how to create and refine data, train R models, and perform scoring on the SQL Server machine. The final scored database table in SQL Server gives the recommendations for **how** and **when** to contact each lead. This data is then visualized in PowerBI.  Also in PowerBI is a summary of the success of the recommendations after your new campaign has completed (shown in this template with simulated data).


Data scientists who are testing and developing solutions can work from the convenience of their R IDE on their client machine, while <a href="https://msdn.microsoft.com/en-us/library/mt604885.aspx" target=_blank">pushing the compute to the SQL Server machine</a>.  They can then deploy the completed solutions to SQL Server 2016 by embedding calls to R in stored procedures. These solutions can then be further automated by the use of SQL Server Integration Services and SQL Server agent.

This solution packet includes the R code a data scientist would develop in the **R** folder.  It shows the stored procedures (.sql files) that can be deployed in the **SQLR** folder.  Finally, there are four PowerShell scripts (.ps1 files) that automate the running of the SQL code.
 
To try this out yourself: 
* Download this template by navigating to the top folder in this repository and using the **Clone or Download** button.
* In the downloaded folder, navigate to the **CampaignManagement/Resources/Instructions** directory
* Follow the instructions in **START HERE.docx** to setup your SQL environment 
* Follow the instructions for running the fully automated solution in **PowerShell Instructions.docx**
* (OPTIONAL) You could also step through the parts of this solution with SQL files by using **SQLR Instructions.docx**
* (OPTIONAL) You can step through the R code in your own R IDE by following the instructions in **R Instructions.docx**


If you need a trial version of SQL Server 2016, see [What's New in SQL Server 2016](https://msdn.microsoft.com/en-us/library/bb500435.aspx) for download or VM options. 

The rest of this page describes what happens in each of the steps: dataset creation, model development, scoring, and deployment in more detail.

##  Analytical Dataset Creation

This templage simulates input data and performs preprocessing and feature engineering to create the analytical dataset. 

The R code to perform these steps can be run from an R client with the following scripts:

* **Step1_input_data.R**:  Simulates the 4 input datasets
* **Step2_data_preprocessing.R**: Performs preprocessing steps like outlier treatment and missing value treatment on the input datasets 
* **Step3_feature_engineering_AD_creation.R**:  Performs Feature Engineering and creates the Analytical Dataset

The R scripts were originally developed and executed in an R IDE. Once complete, the R code was operationalized in .sql files to be executed through T-SQL.   The diagram below shows the .sql files used to perform these actions, incorporating the code from the R scripts above. 

Finally, the **Analytical Dataset Creation.ps1** script was developed be used to automate the the execution of these .sql files.  
 
![Data Creation](Images/datacreate.png?raw=true)



## Model Development
Two models, Random Forest and Gradient Boosting are developed to model Campaign Responses.  The R code to develop these models is included in the **Step4_model_rf_gbm.R script**.

This R code is incorporated into following .sql files, automated in the **Model Development.ps1** script.

![Model Development](Images/model.png?raw=true)



##  Scoring

The models are compared and the champion model is used for scoring.  The prediction results from the scoring step are the recommendations for contact for the campaigns - when and how to contact each lead for the optimal predicted response rate.

The R code for this step is also included in the **Step4_model_rf_gbm.R script**.

The .sql files using this code are present in **step6_models_comparision.sql** which was included in the **Model Development.ps1** script, while the 
scoring is accomplished in the <b>step7\*.sql</b> files, automated by **Scoring.ps1**.

![Scoring](Images/model_score.png?raw=true)

  
##  Deployment / Visualize Results
The deployed data resides in a newly created database table, showing recommendations for each lead.  The final step of this solution visualizes these recommendations, and once the new campaigns have been completed we can also visualize a summary of how well the model worked.  

![Visualize](Images/visualize.png?raw=true)

You can find an example of this in the  [CampaignManagement Dashboard](Campaign%20Management%20Dashboard.pbix).  How to use this template for new data is included in the **Instructions** folder.

##Template Contents 

[View the contents of this solution template](contents.md)

##System Requirements

To run the scripts requires the following:

- SQL Server 2016 with Microsoft R server installed and configured.     
- The SQL user name and password, and the user configured properly to execute R scripts in-memory;
- SQL Database which the user has write permission and execute stored procedures;
- For more information about SQL server 2016 and R service, please visit: [https://msdn.microsoft.com/en-us/library/mt604847.aspx](https://msdn.microsoft.com/en-us/library/mt604847.aspx)


To try this template out yourself: 
* Download this template by navigating to the top folder in this repository and using the **Clone or Download** button.
* In the downloaded folder, navigate to the **CampaignManagement/Resources/Instructions** directory
* Follow the instructions in **START HERE.docx** to setup your SQL environment 
* Follow the instructions for running the fully automated solution in **PowerShell Instructions.docx**
* (OPTIONAL) You could also step through the parts of this solution with SQL files by using **SQLR Instructions.docx**
* (OPTIONAL) You can step through the R code in your own R IDE by following the instructions in **R Instructions.docx**


[&lt; Back to ReadMe](../readme.md)

