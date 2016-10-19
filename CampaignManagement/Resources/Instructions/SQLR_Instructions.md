<img src="../Images/management.png" align="right">
<h1>Campaign Management:
Execution with SQLR Scripts</h1>

Make sure you have set up your SQL Server and ODBC connection between SQL and PowerBI by following the instructions in <a href="START_HERE.md">START HERE</a>.  Then proceed with the steps below to run the solution template using the automated PowerShell files. 


Running these .sql scripts will walk through the operationalized steps of this solution  – dataset creation, modeling, and scoring as described  [here](../data-scientist.md).

<h2>Solution Path:  SQLR Scripts</h2>
The steps below walk you through the execution each of the SQLR scripts - see the [SQLR directory readme](../../SQLR/readme.md) for a detailed description of each of these scripts.

Let’s start in SQL Server Management Studio where we have connected to the SQL 2016 server.  
Login to SSMS using the credential created in [START HERE](START_HERE.md).

The first step we need to do is import the raw datasets into the SQL Server. In this solution we will use a PowerShell window to import the raw datasets into SQL Server.  
 

1.	Click on the windows key on your keyboard. Type the words `PowerShell` and open the Windows PowerShell.


2.	In the Powershell command window, type the following command:
 ```
 Set-ExecutionPolicy Unrestricted -Scope Process
 ```
Answer `y` to the prompt to allow the following scripts to execute.

3.  Now CD to the **SQLR** directory and run the following command, inserting your server name (or "." if you are on the same machine as the SQL server)
```
.\Campaign_Management.ps1 -ServerName "Server Name" -DBName "Campaign_Management"
```
4.  Answer the prompts...**MORE HERE WALK THROUGH EACH PROMPT**

22.	Once the PowerShell script has run, log into the SQL Server to view all the datasets that have been created in the `CampaignManagement` database.  Hit `Refresh` if necessary.
 <br/>
 <img src="../Images/alltables.png" width="30%">

 Right click on `dbo.Recommendations` and select `View Top 1000 Rows` to preview the scored data.
 
<h2>Visualizing Results </h2>
Now proceed to <a href="Visualize_Results.md">Visualizing Results with PowerBI</a>.

## Other Solution Paths
You have just completed the steps of the process using T-SQL commands to simulate data, train and score models.

See the [Typical Workflow Walkthrough](Typical_Workflow.md) for a description of how these files were created.

You may also want to try out the fully automated solution that simulates the data, trains and scores the models by executing PowerShell scripts. This is the fastest way to deploy. See [PowerShell Instructions](Powershell_Instructions.md) for this deployment.
