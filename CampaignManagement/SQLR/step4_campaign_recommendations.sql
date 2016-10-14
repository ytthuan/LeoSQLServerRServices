
/****** Stored Procedure to create a table that has, for each Lead_Id and its corresponding variables (except Day_of_Week, Channel, Time_Of_Day)******/
/****** One row for each possible combination of Day_of_Week, Channel and Time_Of_Day  ******/
SET ANSI_NULLS ON 
GO 
SET QUOTED_IDENTIFIER ON 
GO 

USE Campaign_Management
GO

DROP PROCEDURE IF EXISTS [dbo].[generate_full_table]
GO
CREATE PROCEDURE [generate_full_table]
AS
BEGIN

	DROP TABLE IF EXISTS Day_Of_Week
	DROP TABLE IF EXISTS Time_Of_Day
	DROP TABLE IF EXISTS Channel
	DROP TABLE IF EXISTS Unique_Combos

/* Create table containing all the unique combinations of Day_of_Week, Channel, Time_Of_Day  */
	CREATE TABLE Day_Of_Week (Day_Of_Week nchar(1)) 	
	INSERT INTO Day_Of_Week (Day_Of_Week) VALUES ('1'), ('2'), ('3'), ('4'),('5'),('6'),('7')

	CREATE TABLE Time_Of_Day (Time_Of_Day varchar(15)) 
	INSERT INTO Time_Of_Day (Time_Of_Day) VALUES ('Morning'), ('Afternoon'), ('Evening')

	CREATE TABLE Channel (Channel varchar(15)) 
	INSERT INTO Channel (Channel) VALUES ('Email'), ('Cold Calling'), ('SMS')

	SELECT *
	INTO Unique_Combos
	FROM(SELECT * FROM Channel)  c, (SELECT * FROM Day_Of_Week) d, (SELECT * FROM Time_Of_Day) t
/* Create the full table */
	INSERT INTO AD_full_merged
	SELECT * 
	FROM (
			SELECT Lead_Id, Age, Annual_Income_Bucket, Credit_Score, [State], No_Of_Dependents, Highest_Education, Ethnicity,
			       No_Of_Children, Household_Size, Gender, Marital_Status, Campaign_Id, Product_Id, Product, Term,
			       No_Of_People_Covered, Premium, Payment_frequency, Amt_on_Maturity_Bin, Sub_Category,Campaign_Drivers,
                               Campaign_Name, Call_For_Action, Tenure_Of_Campaign,Net_Amt_Insured, SMS_Count, Email_Count,  Call_Count, 
                               Previous_Channel, Conversion_Flag
			FROM CM_AD) a,
		   (SELECT * FROM Unique_Combos) b

/* Drop intermediate tables */
	DROP TABLE Day_Of_Week
	DROP TABLE Time_Of_Day
	DROP TABLE Channel
	DROP TABLE Unique_Combos
;
END
GO

/****** Stored Procedure to Compute the predicted probabilities for each Lead_Id, for each combination of Day-Channel-Time using best_model****/

DROP PROCEDURE IF EXISTS [dbo].[scoring]
GO

CREATE PROCEDURE [scoring] @best_model varchar(300)

AS
BEGIN
    DECLARE @inquery nvarchar(max) = N'SELECT * FROM AD_full_merged';
    DECLARE @bestmodel varbinary(max) = (SELECT model FROM Campaign_Models WHERE model_name = @best_model);

	/* Increase the memory allocated to R services in order to perform in-memory computations */						
	ALTER RESOURCE POOL "default" WITH (max_memory_percent = 60);  
	ALTER EXTERNAL RESOURCE POOL "default" WITH (max_memory_percent = 40);  
	ALTER RESOURCE GOVERNOR reconfigure; 
	
	INSERT INTO Prob_Id	
	EXEC sp_execute_external_script @language = N'R',
					@script = N'								  

# Get best_model.
best_model <- unserialize(best_model)

# Import the input table AD_full_merged.
AD_full_merged <- InputDataSet

# Score the full data by using the best model. Keep Lead_Id in the prediction table to be able to do an inner join with the full table.
score <- rxPredict(best_model, data = AD_full_merged, type = "prob",
          extraVarsToWrite = c("Lead_Id", "Day_Of_Week","Time_Of_Day","Channel"))

# Change the name of the variable 1_prob so it can be read by SQL then insert it into the SQL table Prob_Id. 
colnames(score)[2] <- c("X1_prob")
score = score[, c(2,4,5,6,7)]

OutputDataSet <- score
'
, @input_data_1 = @inquery
, @params = N' @best_model varbinary(max)' 
, @best_model = @bestmodel     
;

	/* Set back the memory allocation to default. */						
	ALTER RESOURCE POOL "default" WITH (max_memory_percent = 80);  
	ALTER EXTERNAL RESOURCE POOL "default" WITH (max_memory_percent = 20);  
	ALTER RESOURCE GOVERNOR reconfigure; 

END
GO

/****** Stored Procedure to provide, for each Lead_Id, a combination of Day_of_Week, Channel, and Time_Of_Day that has the highest conversion probability  ******/

DROP PROCEDURE IF EXISTS [dbo].[campaign_recommendation]
GO

CREATE PROCEDURE [campaign_recommendation] @best_model varchar(300)
											  
AS
BEGIN

	DROP TABLE IF EXISTS Recommended_Combinations
	DROP TABLE IF EXISTS AD_with_probability
	DROP TABLE IF EXISTS Recommendations

	EXEC [generate_full_table] 
	EXEC [scoring] @best_model = @best_model 

/* Add the probability column to the table AD_full_merged by doing an inner join.  */ 

	SELECT AD_full_merged.Lead_Id, AD_full_merged.Day_of_Week, AD_full_merged.Channel, AD_full_merged.Time_Of_Day, Prob_Id.X1_prob AS Prob1 
	INTO  AD_with_probability
	FROM AD_full_merged JOIN Prob_Id
	ON  AD_full_merged.Lead_Id = Prob_Id.Lead_Id 
	AND AD_full_merged.Day_of_Week = Prob_Id.Day_of_Week 
	AND AD_full_merged.Channel = Prob_Id.Channel
	AND AD_full_merged.Time_Of_Day = Prob_Id.Time_Of_Day
	ORDER BY Lead_Id

	CREATE NONCLUSTERED INDEX idx_prob ON AD_with_probability(Lead_Id, Prob1) INCLUDE (Day_Of_Week, Channel, Time_Of_Day)

/* For each Lead_Id, get one of the combinations of Day_of_Week, Channel, and Time_Of_Day giving highest conversion probability */ 
	
	SELECT Lead_Id, Day_of_Week, Channel, Time_Of_Day, MaxProb
	INTO Recommended_Combinations
	FROM (
		SELECT maxp.Lead_Id, Day_of_Week, Channel, Time_Of_Day, MaxProb, 
		       ROW_NUMBER() OVER (partition by maxp.Lead_Id ORDER BY NEWID()) as RowNo
		FROM (
				SELECT Lead_Id, max(Prob1) as MaxProb
				FROM AD_with_probability
				GROUP BY Lead_Id) maxp
		JOIN AD_with_probability
		ON (maxp.Lead_Id = AD_with_probability.Lead_Id AND maxp.MaxProb = AD_with_probability.Prob1)
         ) candidates
	WHERE RowNo = 1

/* 	Add demographics information to the recommendation table  */

	SELECT Age, Annual_Income_Bucket, Credit_Score, Product, Campaign_Name as [Campaign Name], [State], Conversion_Flag as Converts,
               CM_AD.Day_Of_Week as [Day of Week], CM_AD.Time_Of_Day as [Time of Day], CM_AD.Channel,  CM_AD.Lead_Id as [Lead ID],
	       Recommended_Combinations.Day_Of_Week as [Recommended Day], Recommended_Combinations.Time_Of_Day as [Recommended Time],
	       Recommended_Combinations.Channel as [Recommended Channel], Recommended_Combinations.MaxProb
        INTO Recommendations
	FROM CM_AD JOIN Recommended_Combinations
        ON CM_AD.Lead_Id = Recommended_Combinations.Lead_Id
;
END
GO


		         
