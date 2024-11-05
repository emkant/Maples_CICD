CREATE OR REPLACE EDITIONABLE PROCEDURE "UPDATE_NARRATIVES" 
AS 
L_URL                        VARCHAR2(4000);
  INSTANCE_URL VARCHAR2(200);
    L_VERSION                    VARCHAR2(10);
    L_RESPONSE_CLOB              CLOB;
    L_ENVELOPE                   VARCHAR2(32000);
        V_STATUSCODE                 NUMBER;
BEGIN
  SELECT
    BASE_URL INTO INSTANCE_URL
  FROM
    PRT_ENVIRONMENTS
  WHERE
    ORGANIZATION_ID IN (
      SELECT
        ORGANIZATION_ID
      FROM
        PRT_ORGANIZATIONS
      WHERE
        UPPER(ORGANIZATION_NAME) = 'DEV'
    )
    AND UPPER(ENVIRONMENT_NAME) = 'DEV';
  FOR I IN (SELECT * FROM LOAD_NARRATIVES-- WHERE EXPENDITURE_ITEM_ID = 527257
  )
  LOOP
    L_URL := INSTANCE_URL
             || '/fscmRestApi/resources/11.13.18.05/projectExpenditureItems/'
             || I.EXPENDITURE_ITEM_ID
             || '/child/ProjectExpenditureItemsDFF/'
             || I.EXPENDITURE_ITEM_ID;
    L_ENVELOPE := '{"narrativeBillingOverflow1" : "'
                  || I.INVOICE_NARRATIVE
                   ||'"
                   }';             
     APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/json';
    L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST ( P_URL => L_URL, P_HTTP_METHOD => 'PATCH',
 p_username => 'AMY.MARLIN',
 p_password => 'F8*xe7?M',
 -- P_CREDENTIAL_STATIC_ID => 'GPMS_DEV',
    -- P_SCHEME => 'OAUTH_CLIENT_CRED',
     P_BODY => L_ENVELOPE );
    V_STATUSCODE := APEX_WEB_SERVICE.G_STATUS_CODE;    
    -- XX_GPMS.WIP_DEBUG (2, 7777, '', V_STATUSCODE||' '||I.EXPENDITURE_ITEM_ID);   
        DBMS_OUTPUT.PUT_LINE(L_URL);        
    DBMS_OUTPUT.PUT_LINE(L_ENVELOPE);    
  END LOOP;
 END;
/