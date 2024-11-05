CREATE OR REPLACE EDITIONABLE PROCEDURE "XX_JWT_USERNAME1" (l_str IN VARCHAR2)  
 is    
i number;  
  
begin  
i := 0;  
  
INSERT INTO axxml_tab 
                ( 
                        session_id, 
                        id, 
                        vc2_data, 
                        xml_clob 
                ) 
                VALUES 
                ( 
                        V('APP_SESSION'), 
                        999, 
                        l_str, 
                        NULL 
                         
                ); 
      
end; 
/