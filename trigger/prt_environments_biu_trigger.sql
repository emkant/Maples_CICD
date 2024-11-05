CREATE OR REPLACE EDITIONABLE TRIGGER "PRT_ENVIRONMENTS_BIU" 
BEFORE INSERT OR UPDATE ON PRT_ENVIRONMENTS FOR EACH ROW 
BEGIN 
  IF INSERTING THEN 
    :new.created_by         := nvl(v('APP_USER'),USER); 
    :new.creation_date      := SYSTIMESTAMP; 
  END IF; 
  :new.last_updated_by    := nvl(v('APP_USER'),USER); 
  :new.last_update_date   := SYSTIMESTAMP; 
END; 
 

/
