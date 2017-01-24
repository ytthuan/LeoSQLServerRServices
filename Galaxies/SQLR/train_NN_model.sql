-- =============================================
-- Description:	Galaxies Training with Microsoft ML Neural Nets.
-- =============================================
CREATE PROCEDURE [dbo].[TrainGalaxiesNN] 
	
AS
BEGIN

	SET NOCOUNT ON;
	-- Construct the RML script.
	declare @cmd nvarchar(max)
	set @cmd = N'
library(MicrosoftML)
library(dplyr)

set.seed(123)
dataParms <- list(
  image_root     = "C:/Galaxies/data",
  outmodel_root  = "C:/Galaxies/models",
  training_rows = 238000,
  test_rows     = 1500
)

hyperParms <- list(
  comment = "Add rotations for 45 and 90 degrees, test on 10K rows, increase iterations to 250",
  augmentation = "none",
  netDefSummary = "conv(6x6) => norm() => pool(2x2) => conv(5x5) => norm() => pool(2x2) => full(128) => full(128) => out(13)",
  numIterations = 250,
  miniBatchSize = 128,
  acceleration = "gpu"
)

optimParms <- list(
  optimizer = "sgd",
  learningRate = 0.05,
  lRateRedRatio = 0.99,
  lRateRedFreq = 5,
  momentum = 0.2,
  decay = 0.95,
  conditioningConst = 1e-6
)

# Read csv with Labels info.
dat_all <- read.csv("C:/Galaxies/data/galaxiesTraining.csv",  stringsAsFactors = FALSE)
dat_all$specobjid <- as.character(dat_all$specobjid)
dat_all$toplevel_class <- as.factor(dat_all$toplevel_class)

sample_train <- base::sample(nrow(dat_all), 
                             size = dataParms$training_rows)
sample_test  <- base::sample((1:nrow(dat_all))[-sample_train], 
                             size = dataParms$test_rows)

dat_train <- dat_all %>% 
  slice(sample_train) 

dat_test <- dat_all %>% 
  slice(sample_test)

 
# This function assists with images loading during training.
# It s called from mlTransforms and uses Microsoft ML internal features that a subject to change.
# Next release will have more elagant solution.
getBitmapLoader <- function(mode)
{
  if (mode == "path" )
    return("BitmapLoaderTransform{col=Image:path}")
  if (mode == "scaler" )
    return("BitmapScalerTransform{col=bitmap:Image width=50 height=50}")
  if (mode == "pixel" )
    return("PixelExtractorTransform{col=pixels:bitmap}")
}

# Data augmentation: adding the rotations.
dat_train <- dat_train %>% 
  bind_rows(
    dat_train %>% mutate(
      path = gsub("raw-resized", "raw-resized-rotated-45", path)
    ) %>% bind_rows(
      dat_train %>% mutate(
        path = gsub("raw-resized", "raw-resized-rotated-90", path)
      ) 
    )
  )

# Define NN using Net# language.
# See https://docs.microsoft.com/en-us/azure/machine-learning/machine-learning-azure-ml-netsharp-reference-guide for more info.
netDefinition <- ("input pixels [3, 50, 50];
                  hidden conv1 [64, 23, 23] rlinear from pixels convolve {
                  InputShape = [3, 50, 50];
                  KernelShape = [3, 6, 6];
                  Stride = [1, 2, 2];
                  Sharing = [false, true, true];
                  MapCount = 64;
                  }
                  hidden norm1 [64, 23, 23] from conv1 response norm {
                  InputShape = [64, 23, 23];
                  KernelShape = [1, 1, 1];
                  Alpha = 0.0001;
                  Beta = 0.75;
                  Offset = 1;
                  AvgOverFullKernel = true;
                  }
                  hidden pool1 [64, 12, 12] from norm1 max pool {
                  InputShape = [64, 23, 23];
                  KernelShape = [1, 2, 2];
                  Stride = [1, 2, 2];
                  Padding = [true, true, true];
                  }
                  hidden conv2 [128, 5, 5] rlinear from pool1 convolve {
                  InputShape = [64, 12, 12];
                  KernelShape = [1, 5, 5];
                  Stride = [1, 2, 2];
                  LowerPad = [0, 1, 1];
                  Sharing = [false, true, true];
                  MapCount = 2;
                  }
                  hidden norm2 [128, 5, 5] from conv2 response norm {
                  InputShape = [128, 5, 5];
                  KernelShape = [1, 1, 1];
                  Alpha = 0.0001;
                  Beta = 0.75;
                  Offset = 1;
                  AvgOverFullKernel = true;
                  }
                  hidden pool2 [128, 3, 3] from norm2 max pool {
                  InputShape = [128, 5, 5];
                  KernelShape = [1, 2, 2];
                  Stride = [1, 2, 2];
                  Padding = [true, true, true];
                  }
                  hidden hid1 [128] rlinear from pool2 all;
                  hidden hid2 [128] rlinear from hid1 all;
                  output Class [13] softmax from hid2 all;"
)

optimiser <- with(optimParms, sgd(learningRate  = learningRate,
                                  lRateRedRatio = lRateRedRatio,
                                  lRateRedFreq  = lRateRedFreq,
                                  momentum      = momentum))


model <- rxNeuralNet(toplevel_class ~ pixels, data = dat_train,
                   type            = "multiClass",
                   mlTransformVars = "path",
                   mlTransforms    = list(
                     getBitmapLoader("path"),
                     getBitmapLoader("scaler"),
                     getBitmapLoader("pixel") 
                   ),
                   netDefinition = netDefinition, 
                   optimizer     = optimiser,
                   acceleration  = hyperParms$acceleration,
                   miniBatchSize = hyperParms$miniBatchSize,
                   numIterations = hyperParms$numIterations,
                   normalize       = "no",
                   initWtsDiameter = 0.1,
                   verbose         = 1,
                   postTransformCache = "Disk")

trained_model <- data.frame(payload = as.raw(serialize(model, connection=NULL)));
	'

	create table #m (model varbinary(max));
	insert into #m
	execute sp_execute_external_script
	  @language = N'R'
	, @script = @cmd
	, @output_data_1_name = N'trained_model ';

	
	insert into [dbo].GalaxiesModels(CreationDate, Model, [Name]) 
	select CURRENT_TIMESTAMP as timest, model, 'prod' as summary from #m;  

	drop table #m
END
