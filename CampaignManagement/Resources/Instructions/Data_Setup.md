<img src="../Images/management.png" align="right">
<h1>Campaign Management:
Data Setup</h1>

<h2>Modify Scripts for Quick Execution</h2>

For the purposes of a quick demo, we need to use a small dataset. To create a smaller dataset follow the below steps.  (This will modify the data size when using the SQLR solution path or the Powershell solution path.)

1.	Open `step1(c)_lead_demography.sql`. Press `Ctrl + G`. Enter `55` and press `Enter`. This will take you to the 55th line of the code. Change the value `100000` to `10000` for the purpose of a quick demo.
<br/>
<img src="../Images/data1.png"> 
	
2.	Open `step5(a)_model_train_rf.sql`. Press `Ctrl + G`. Enter `48` and press `Enter`. This will take you to the 48th line of the code. Change the value `500` to `75` for the purpose of a quick demo.
<br/>
<img src="../Images/data2.png"> 

3.	Open `step5(c)_model_train_gbm.sql`. Press `Ctrl + G`. Enter `64` and press `Enter`. This will take you to the 64th line of the code. Change the value `500` to `75` for the purpose of a quick demo.
 <br/>
<img src="../Images/data3.png">

<h2>Ready to Run Code</h2>
+ For the fully automated experience, see [PowerShell Instructions](Powershell_Instructions.md).

+ Alternatively, if you wish to step-through the process from the perspective of a data scientist using your R IDE, see the [R Instructions](R_Instructions.md).

+ Finally, we have also prepared a version that steps through the process using T-SQL commands. To do so, follow the [SQLR Instructions](SQLR_Instructions.md).