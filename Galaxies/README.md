# Galaxies classification with SQL Server 2016 R Services and Mirosoft ML

This sample has supporting SQL scripts for the blogpost [How six lines of code + SQL Server can bring Deep Learning to ANY App](https://blogs.technet.microsoft.com/dataplatforminsider/2017/01/05/how-six-lines-of-code-sql-server-can-bring-deep-learning-to-any-app/).

[Galaxy Zoo](https://www.galaxyzoo.org/) project was used as source of labeled training data.

Sample has the following structure:
1) SQLR folder has scripts for SQL Stored procedures that use R Services for training model and prediction.
2) SQL fodler has scripts that create tables used during training and prediction. It also has script for SQL Trigger that is uses to invoke prediction flow.