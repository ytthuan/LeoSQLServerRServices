/* create the procedure to train model by calling R */
/* to execuate: exec dbo.TrainModelR; */

set ansi_nulls on
go

set quoted_identifier on
go

DROP PROCEDURE IF EXISTS TrainModelR
GO

create procedure TrainModelR
as
begin

truncate table sql_trained_model

insert into sql_trained_model
execute sp_execute_external_script
  @language = N'R',
  @script = N' 
  train_all <- InputDataSet
  # exclude records with Label>1
  train <- subset(train_all,Label<=1)

  # make the Label as factor
  train$Label <- as.factor(train$Label)

  # specify variables should be numeric but stored as string in sql table
  numeric_names <- c("transactionAmountUSD",
                   "transactionAmount",
                   "digitalItemCount",
                   "physicalItemCount",
                   "accountAge",
                   "paymentInstrumentAgeInAccount",
                   "sumPurchaseAmount1dPerUser",
                   "sumPurchaseAmount30dPerUser",
                   "sumPurchaseCount1dPerUser",
                   "sumPurchaseCount30dPerUser",
                   "numPaymentRejects1dPerUser")

  # convert string to be numeric and delet NA value generated during converting
  # some column like account state has string containing comma, which causes problem when uploading data.
  # This is the reason some numeric variables have string value and NA will occur when converting it into numeric
  id <- which(colnames(train) %in% numeric_names)
  for(i in 1:length(id)){
    train[,id[i]] <- as.numeric(as.character(train[,id[i]]))
    id_na <- which(is.na(train[,id[i]]) ==TRUE)
    if(length(id_na) > 0){train[id_na,id[i]] <- 0}
  }

  # train GBT model
  names <- colnames(train)[which(colnames(train) != "Label")]
  equation <- paste("Label ~ ", paste(names, collapse = "+", sep=""), sep="")
  boosted_fit <- rxBTrees(formula = as.formula(equation),
                          data = train,
                          learningRate = 0.2,
                          minSplit = 10,
                          minBucket = 10,
                          nTree = 100,
                          seed = 5,
                          lossFunction = "bernoulli")
  
  trained_model <- data.frame(model=as.raw(serialize(boosted_fit, NULL)))
  ',
  @input_data_1 = N' select top 10000 * from sql_tagged_training order by Label DESC', -- choose top 10000 to train, for the purpose of 1) speed up 2) down sample to improve performance
  @output_data_1_name = N'trained_model'
 ;
 end
