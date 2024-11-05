CREATE OR REPLACE EDITIONABLE PROCEDURE "TEST_REST" (g_user_name in varchar2 ,g_password in varchar2)
as
  l_clob clob;
  L_URL  VARCHAR2(1000) ;
  INSTANCE_URL VARCHAR2(1000);
begin
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/json';
    SELECT
    BASE_URL 
    INTO INSTANCE_URL
  FROM
    PRT_ENVIRONMENTS
  WHERE
    ORGANIZATION_ID IN (
      SELECT
        ORGANIZATION_ID
      FROM
        PRT_ORGANIZATIONS
      WHERE
        UPPER(ORGANIZATION_NAME) = 'MAPLES'
    )
    AND UPPER(ENVIRONMENT_NAME) = 'DEV1';
   
  L_URL := INSTANCE_URL||'/fscmRestApi/resources/11.13.18.05/projectExpenditureItems';
  L_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST ( P_URL => L_URL
                                                                  , P_HTTP_METHOD => 'GET',
                                                                  p_username => g_user_name,
                                                                  p_password => g_password);
  dbms_output.put_line(APEX_WEB_SERVICE.G_STATUS_CODE);                                                                  
exception
  when others then
    dbms_output.put_line(sqlerrm);                                                                
    null;
end "TEST_REST";
/