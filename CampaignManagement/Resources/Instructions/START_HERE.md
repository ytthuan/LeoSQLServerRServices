<img src="../Images/management.png" align="right">
<h1>Campaign Management:
START HERE: Setup </h1>

Prepare your SQL Server 2016 Installation
Complete the steps in the Set up SQL Server R Services (In-Database) Instructions. The set up instructions file can found at  <a href="https://msdn.microsoft.com/en-us/library/mt696069.aspx" target="_blank"> https://msdn.microsoft.com/en-us/library/mt696069.aspx</a>

Set up logins in SQL Server
<ol>
<li>	In SSMS, connect to the Server with your admin account</li>
<li>	Create a new user: Right click on Security and select New &gt; Login <br/>
<br/>
<img src="../Images/newuser.png" width="50%" >
</li>
 
<li>	If you haven’t already done so, create a new Windows authentication user with the Login name “&lt;machinename&gt;\SQLRUserGroup”
To find your computer name. Open System by clicking the Start button, right-click Computer, and then click Properties. Under Computer name, domain, and workgroup settings, you can find your computer name and full computer name if your computer is on a domain.
<br/>
<img src="../Images/sqluser.png" width="75%" >
</li>
 


(It is mandatory to use the Trusted Connection method of accessing the database in an R connection string.)

<li>	Create the "rdemo" user  by opening the Resources/createuser.sql file and executing it.
 (This user login will be used to install data and procedures via the PowerShell script in a later step in this setup).
<br/>
<img src="../Images/rdemo.png" width="50%" >
    </li>
<li>	In the Object Explorer, select this new user and double click or right click and select Properties.  (If you don’t see the new user, right click on “Logins” and select “Refresh” first.)
<br/>
<br/>
<img src="../Images/rdemoprop.png" width="75%" >
</li>
 
<li>	On the Server Roles tab check public and sysadmin.
<br/>
<img src="../Images/rdemoprop2.png" width="75%" > 
</li>

<li>	On the User Mapping tab, check “master” in the top section, then check db_datareader, db_datawriter, db_owner, and public in the bottom table.
<br/>
<img src="../Images/rdemoprop2.png" width="75%" >
</li>
 
<li>	Check to make sure you have set your Server Authentication mode to SQL Server and Windows Authentication mode.  
    <ul>
<li>	In SQL Server Management Studio Object Explorer, right-click the server, and then click Properties.</li>
<li>	On the Security page, under Server authentication, select “SQL Server and Windows Authentication mode” if it is not already selected.</li>
 <br/>
<img src="../Images/authmode.png" width="75%" >
<li>	In the SQL Server Management Studio dialog box, click OK.  If you changed the mode in the previous step, you will need to also acknowledge the requirement to restart SQL Server.</li>
<li>	If you changed the mode, restart the server.  In the Object Explorer, right-click your server, and then click Restart. If SQL Server Agent is running, it must also be restarted.</li>
</ul></li>

<li>	Now, click on 'File' on the top left corner of the SQL Server window and select 'Connect Object Explorer…' verify that you can connect to the server with this username(<b>rdemo</b>) &amp; password(<b>D@tascience</b>).</li>
</ol>

 

<h2>Install data.table Package on SQL</h2>
<p>	Install the data.table  package into SQL R: </p>
<ol>
<li>	On the machine with your server, open a command window  as “Administrator” and submit the following commands:
<pre><code>
cd "C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\R_SERVICES\bin"
R
</code></pre>
</li>
<li>	Once you see the R prompt, execute the following commands:
<pre><code>
install.packages("data.table")
install.packages("ROCR")
q()
n
</code></pre>
</li>
</ol>

<h2>Create Database</h2>
In SSMS, create the “CampaignManagement” Database to be used for this solution.
 

<h3>Set up Connection between SQL Server and PowerBI</h3>
<ol>
<li>	Push the Windows key on your keyboard</li>
<li>	Type ODBC</li>
<li>	Open the correct app depending on what type of computer you are using (64 bit or 32 bit). To find out if your computer is running 32-bit or 64-bit Windows, do the following:</li>
<ol><li>	Open System by clicking the Start button, clicking Control Panel, clicking System and Maintenance, and then clicking System
<li>.	Under System, you can view the system type</li></ol></li>
<li>	Click on ‘Add’
  <br/>
<img src="../Images/odbc1.png" width="50%" >
</li>
<li>	Select ‘Server Native Client 11.0’ and click finish
   <br/>
<img src="../Images/odbc2.png" width="50%" >
 </li>
<li>	Under Name, Enter ‘CampaignManagement’. Under Server enter the MachineName from the SQL Server logins set up section. Press ‘Next’
   <br/>
<img src="../Images/odbc3.png" width="50%" >
</li>
<li>	Select SQL Server authentication and enter the credentials you created in the SQL Server set up section. Press ‘Next’
   <br/>
<img src="../Images/odbc4.png" width="50%" >
</li>
 

<li>	Check the box for ‘Change the default database to’ and enter ‘CampaignManagement’. Press ‘Next’
   <br/>
<img src="../Images/odbc5.png" width="50%" >
</li>
<li>Press ‘Finish’
  <br/>
<img src="../Images/odbcfinish.png" width="50%" > 
</li>
<li>Press ‘Test Data Source’
  <br/>
<img src="../Images/odbc6.png" width="50%" >
</li> 
<li>	Press ‘OK’ in the new popover. This will close the popover and return to the previous popovers
   <br/>
<img src="../Images/odbc7.png" width="50%" >
</li>
<li>	Now that the Data Source is tested. Press ‘OK’
   <br/>
<img src="../Images/odbc8.png" width="50%" >
</li>
<li>	Finally, click ‘OK’ and close the window 
   <br/>
<img src="../Images/odbc9.png" width="50%">
</li>
</ol>
<h2>Ready to Run Code</h2>
You are now ready to run the code for this solution.

Typically a data scientist will create and test a predictive model from their favorite R IDE, at which point the models will be stored in SQL Server and then scored in production using Transact-SQL (T-SQL) stored procedures. 

If you’re just interested in the outcomes of this process we have created a fully automated solution that simulates the data, trains and scores the models by executing PowerShell scripts. This is the fastest way to deploy. See [PowerShell Instructions](Powershell_Instructions.md) for this deployment.

Alternatively, if you wish to step-through the process from the perspective of a data scientist using your R IDE, see the [R Instructions](R_Instructions.md).

Finally, we have also prepared a version that steps through the process using T-SQL commands. To do so, follow the [SQLR Instructions](SQLR_Instructions.md).
	