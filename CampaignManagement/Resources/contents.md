<img src="Images/management.png" align="right">
# Campaign Management Template with SQL Server 2016 R Services – Template Contents

The following is the directory structure for this template:

- [**Data**](#copy-of-input-datasets)  This contains the copy of the simulated input data
- [**R**](#model-development-in-r)  This contains the R codes to simulate the input datasets, create the analytical datasets, train the models, identify champion model and score the analytical/scorings dataset
- [**Resources**](#resources-for-the-solution-packet) This directory contains the detailed description and instructions for this packet as well as the PowerBI file used to visualize results
- [**SQLR**](#model-development-in-sql-server-2016-r-services) This contains the SQLR codes to simulate the input datasets, create the analytical datasets, train the models, identify champion model and score the analytical/scorings dataset. It also contains PowerShell scripts automate the entire process

In this template with SQL Server R Services, three versions of the implementation module have been showcased:

1. [**Model Development in R IDE**](#model-development-in-r)  . Run the R code in R IDE (e.g., RStudio, R Tools for Visual Studio).
2. [**Model Development in SQL**](#model-development-in-sql-server-2016-r-services). Run the SQL code in SQL Server using SQLR scripts
3. [**Automation in PowerShell**](#automation-with-powershell). Run the PowerShell scripts which automates the Model Development and Scoring Process


## Copy of Input Datasets

| File | Description |
| --- | --- |
| .\Data\campaign\_detail.csv | Campaign Metadata |
| .\Data\market\_touchdown.csv | Historical Campaign data including lead responses |
| .\Data\product.csv | Product Metadata |
| .\Data\lead\_demography.csv | Demographic data of the leads |

## Model Development in R

| File | Description |
| --- | --- |
| .\R\input\_data.r | Simulates the 4 input datasets |
| .\R\feature\_engineering.r | Performs Feature Engg. On the input datasets |
| .\R\RF\_model\_train.r | Builds Random Forest Model |
| .\R\GBM\_model\_train.r | Builds Gradient Boosting Model |

Follow the [R Instructions](Instructions/R_Instructions.md) to execute these scripts.


## Model Development in SQL Server 2016 R Services

| File | Description |
| --- | --- |
| .\SQLR\step0\_table\_structure\_input\_data.sql | SQL Script to create schema of the databases if the user wants to import the datasets instead of simulating them |
| .\SQLR\step1(a)\_campaign\_detail.sql | SQLR Script to create the campaign detail dataset |
| .\SQLR\step1(b)\_product.sql | SQLR Script to create Product dataset |
| .\SQLR\step1(c)\_lead\_demography.sql | SQLR Script to create Lead Demography dataset |
| .\SQLR\step1(d)\_market\_touchdown.sql | SQLR Script to create Market Touchdown dataset |
| .\SQLR\step2(a)\_preprocessing\_market\_touchdown.sql  | Outliers in the market touchdown dataset are treated |
| .\SQLR\step2(b)\_preprocessing\_lead\_demography.sql | Missing values in the Lead demography table are treated |
| .\SQLR\step3\_feature\_engineering\_market\_touchdown.sql | Market touchdown dataset is aggregated and variables like #Emails, #Calls and #SMS are created |
| .\SQLR\step4\_ad\_creation.sql | SQLR Script to create Analytical Dataset and split it into Train and Test |
| .\SQLR\Step5(a)\_model\_train\_rf.sql | SQLR Script build Random Forest |
| .\SQLR\Step5(b)\_model\_train\_rf.sql | SQLR Script build Gradient Boosting Model |
| .\SQLR\step6\_models\_comparision.sql | SQLR Script to compute the model statistics of both the models |
| .\SQLR\step7\_scoring\_leads.sql | SQLR Script to select the champion model and score the Analytical dataset on the champion model |

Follow the [SQLR Instructions](Instructions/SQLR_Instructions.md) to execute these scripts.


## Automation with PowerShell
| File | Description |
| --- | --- |
| .Analytical Dataset Creation.ps1 | Creates the Analytical/Scoring dataset |
| .Model Development.ps1 | Trains the Random Forest and Gradient Boosting Models |
| .Scoring.ps1 | Identifies the Champion Model and scores the Analytical/Scoring dataset |

Follow the [PowerShell Instructions](Instructions/Powershell_Instructions.md) to execute these scripts.


## Resources for the Solution Packet
| File | Description |
| --- | --- |
| .\Resources\business-manager.md | Describes the solution for the Business Manager |
| .\Resources\Campaign Management Dashboard.pbix | PowerBI Dashboard showing the recommendation results |
| .\Resources\contents.md | This document |
| .\Resources\createusr.sql | used during initial setup, referenced in **.\Resources\Instructions\START HERE.docx** |
| .\Resources\data-scientist.md | Describes the solution for the Data Scientist |
| .\Resources\Microsoft - Campaign Management.pptx | Powerpoint description of the solution packet |
| .\Resources\Images\ | Directory of images used for the various Readme.md files in this packet |

###  Instructions for Running this Solution Packet
| File | Description |
| --- | --- |
| .\Resources\Instructions\Data Setup.md | [Use this to setup data](Instructions\Data_Setup.md) for a quick or more detailed execution |
| .\Resources\Instructions\Powershell_Instructions.md | [Instructions for running the solution from PowerShell](Instructions\Powershell_Instructions.md) |
| .\Resources\Instructions\R_Instructions.md | [Instructions for running the solution in R](Instructions\R_Instructions.md) on a local machine |
| .\Resources\Instructions\START_HERE.md | **[START HERE](Instructions\START_HERE.md)** to learn how to set up your computer for all solution paths |
| .\Resources\Instructions\Visualize_Results.md | [Instructions for visualizing your results](Instructions\Visualize_Results.md) in the PowerBI template |




[&lt; Back to ReadMe](../readme.md)