# Galaxies classification with Deep Learning from Mirosoft ML using SQL Server R Services

This sample provides the supporting SQL and R scripts for the blogpost [How six lines of code + SQL Server can bring Deep Learning to ANY App](https://blogs.technet.microsoft.com/dataplatforminsider/2017/01/05/how-six-lines-of-code-sql-server-can-bring-deep-learning-to-any-app/).

**Data**: [Galaxy Zoo](https://www.galaxyzoo.org/) project was used as source of labeled training data.

**Scripts**: The following scripts are provided

- createTables.sql: create tables for trained models and scored data.
- train_NN_model.sql: stored procedure for training NN model with Microsoft ML
- predict_NN_model.sql: stored procedure for scoring
- trigger_predict_model.sql: script to invoke scoring.

For end-to-end training and prediction the images could be downloaded from public storage.
See this links for more info:
http://skyserver.sdss.org/dr13/en/help/browser/browser.aspx#&&history=description+zoo2MainSpecz+U
https://arxiv.org/pdf/1308.3496v2.pdf
http://skyserver.sdss.org/dr13/en/tools/search/sql.aspx
