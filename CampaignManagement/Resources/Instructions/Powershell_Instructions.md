<img src="../Images/management.png" align="right">
OLD INFO... NEEDS UPDATING.
<h1>Campaign Optimization:
Execution with PowerShell</h1>


Running these PowerShell scripts performs the automated version of the solution – dataset creation, modeling, and scoring as described  [here](../data-scientist.md).


<img src="../Images/management.png" align="right">
<h1>Campaign Optimization:
Execution with SQLR Scripts</h1>

Make sure you have set up your SQL Server and ODBC connection between SQL and PowerBI by following the instructions in <a href="START_HERE.md">START HERE</a>.  Then proceed with the steps below to run the solution template using the automated PowerShell files. 


Running these .sql scripts will walk through the operationalized steps of this solution  – dataset creation, modeling, and scoring as described  [here](../data-scientist.md).

<h2>Solution Path:  SQLR Scripts</h2>
The steps below walk you through the execution each of the SQLR scripts - see the [SQLR directory readme](../../SQLR/readme.md) for a detailed description of each of these scripts.

Let’s start in SQL Server Management Studio where we have connected to the SQL 2016 server.  
Login to SSMS using the credential created in [START HERE](START_HERE.md).

The first step we need to do is import the raw datasets into the SQL Server. In this solution we will use a PowerShell window to import the raw datasets into SQL Server.  
 

1.	Click on the windows key on your keyboard. Type the words `PowerShell`.  Right click on Windows Powershell to and select `Run as administrator` to open the PowerShell window.


2.	In the Powershell command window, type the following command:
 ```
 Set-ExecutionPolicy Unrestricted -Scope Process
 ```
Answer `y` to the prompt to allow the following scripts to execute.

3.  Now CD to the **SQLR** directory and run the following command, inserting your server name (or "." if you are on the same machine as the SQL server)
```
.\Campaign_Management.ps1 -ServerName "Server Name" -DBName "Campaign"
```
4.  Answer the prompts...**MORE HERE WALK THROUGH EACH PROMPT**

22.	Once the PowerShell script has completed, log into the SQL Server to view all the datasets that have been created in the `CampaignManagement` database.  Hit `Refresh` if necessary.
 <br/>
 <img src="../Images/alltables.png" width="30%">

 Right click on `dbo.Recommendations` and select `View Top 1000 Rows` to preview the scored data.
 
<h2>Visualizing Results </h2>
Now proceed to <a href="Visualize_Results.md">Visualizing Results with PowerBI</a>.



Once the PowerShell script has completed successfully, log into the SQL Server to view all the datasets that have been created in the `CampaignManagement` database.  
Hit `Refresh` if necessary.
<br/>
<img src="../Images/alltables.png" width="30%">

Right click on `dbo.Recommendations` and select `View Top 1000 Rows` to preview the scored data.

## Visualizing Results 
Now proceed to <a href="Visualize_Results.md">Visualizing Results with PowerBI</a>.

## Other Solution Paths

You've just completed the fully automated solution that simulates the data, trains and scores the models by executing PowerShell scripts.  

See the [Typical Workflow Walkthrough](Typical_Workflow.md) for a description of how these files were created and 