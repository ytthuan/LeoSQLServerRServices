--Update script designed to be called from PredictiveMaintenanceModelingGuideSetup.ps1
UPDATE errors SET errorID = REPLACE(errorID, '"','');
UPDATE maint SET comp = REPLACE(comp, '"','');
UPDATE machines SET model = REPLACE(model, '"','');
UPDATE failures SET failure = REPLACE(failure, '"','');