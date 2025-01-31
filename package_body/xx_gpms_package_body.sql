CREATE OR REPLACE EDITIONABLE PACKAGE BODY "XX_GPMS" AS
  INSTANCE_URL VARCHAR2(200);
  P_URL        VARCHAR2(200);
  G_PASSWORD1  VARCHAR2(100);
  G_TOKEN_TS   TIMESTAMP := CAST( TO_TIMESTAMP_TZ( '2023-03-06 17:05:46 GMT', 'YYYY-MM-DD HH24:MI:SS TZR' ) AS TIMESTAMP ) + INTERVAL '4' HOUR;
  PROCEDURE WIP_DEBUG (
    P_DEBUG_LEVEL IN NUMBER,
    P_DEBUG_ID IN NUMBER,
    P_DEBUG_STR IN VARCHAR2,
    P_DEBUG_CLOB IN CLOB
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO AXXML_TAB (
      SESSION_ID,
      ID,
      VC2_DATA,
      XML_CLOB
    ) VALUES (
      V ('APP_SESSION'),
      P_DEBUG_ID,
      P_DEBUG_STR,
      P_DEBUG_CLOB
    );
    COMMIT;
  END WIP_DEBUG;
  FUNCTION BASE64_DECODE_CLOB (
    P_DECODECLOB IN CLOB
  ) RETURN CLOB IS
    BLOB_LOC      BLOB;
    CLOB_TRIM     CLOB;
    RES           CLOB;
    LANG_CONTEXT  INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
    DEST_OFFSET   INTEGER := 1;
    SRC_OFFSET    INTEGER := 1;
    READ_OFFSET   INTEGER := 1;
    WARNING       INTEGER;
    L_CLOB_LENGTH INTEGER := DBMS_LOB.GETLENGTH (P_DECODECLOB);
    AMOUNT        INTEGER := 1440;
 -- must be a whole multiple of 4
    BUFFER        RAW(32000);
    STRINGBUFFER  VARCHAR2(32000);
 -- BASE64 characters are always simple ASCII. Thus you get never any Mulit-Byte character and having the same size as 'amount' is sufficient
  BEGIN
    DBMS_LOB.CREATETEMPORARY (RES, TRUE);
    IF P_DECODECLOB IS NULL OR NVL(L_CLOB_LENGTH, 0) = 0 THEN
      RETURN RES;
    ELSIF L_CLOB_LENGTH <= 32000 THEN
      RES := UTL_RAW.CAST_TO_VARCHAR2 ( UTL_ENCODE.BASE64_DECODE (UTL_RAW.CAST_TO_RAW (P_DECODECLOB)) );
    ELSE -- UTL_ENCODE.BASE64_DECODE is limited to 32k, process in chunks if bigger
 -- Remove all NEW_LINE from base64 string
      L_CLOB_LENGTH := DBMS_LOB.GETLENGTH (P_DECODECLOB);
      DBMS_LOB.CREATETEMPORARY (CLOB_TRIM, TRUE);
      LOOP
        EXIT WHEN READ_OFFSET > L_CLOB_LENGTH;
        STRINGBUFFER := REPLACE( REPLACE( DBMS_LOB.SUBSTR (P_DECODECLOB, AMOUNT, READ_OFFSET), CHR(13), NULL ), CHR(10), NULL );
        DBMS_LOB.WRITEAPPEND (CLOB_TRIM, LENGTH(STRINGBUFFER), STRINGBUFFER);
        READ_OFFSET := READ_OFFSET + AMOUNT;
      END LOOP;
      READ_OFFSET := 1;
      L_CLOB_LENGTH := DBMS_LOB.GETLENGTH (CLOB_TRIM);
      DBMS_LOB.CREATETEMPORARY (BLOB_LOC, TRUE);
      LOOP
        EXIT WHEN READ_OFFSET > L_CLOB_LENGTH;
        BUFFER := UTL_ENCODE.BASE64_DECODE ( UTL_RAW.CAST_TO_RAW (DBMS_LOB.SUBSTR (CLOB_TRIM, AMOUNT, READ_OFFSET)) );
        DBMS_LOB.WRITEAPPEND (BLOB_LOC, DBMS_LOB.GETLENGTH (BUFFER), BUFFER);
        READ_OFFSET := READ_OFFSET + AMOUNT;
      END LOOP;
      DBMS_LOB.CONVERTTOCLOB ( RES, BLOB_LOC, DBMS_LOB.LOBMAXSIZE, DEST_OFFSET, SRC_OFFSET, DBMS_LOB.DEFAULT_CSID, LANG_CONTEXT, WARNING );
      DBMS_LOB.FREETEMPORARY (BLOB_LOC);
      DBMS_LOB.FREETEMPORARY (CLOB_TRIM);
    END IF;
    RETURN RES;
  END BASE64_DECODE_CLOB;
  --
  FUNCTION UPDATE_PROJECT_LINES_DFF (P_EXP_ID IN NUMBER, P_INTERNAL_COMMENT VARCHAR2,
                P_NARRATIVE_BILLING_OVERFLOW IN VARCHAR2 DEFAULT NULL,
                P_EVENT_ATTR IN VARCHAR2 DEFAULT NULL,
                P_STANDARD_BILL_RATE_ATTR IN NUMBER DEFAULT NULL,
                P_PROJECT_BILL_RATE_ATTR IN NUMBER DEFAULT NULL,
                P_REALIZED_BILL_RATE_ATTR IN NUMBER DEFAULT NULL,
                P_HOURS_ENTERED IN NUMBER DEFAULT NULL
                )
  RETURN NUMBER
  IS
    L_URL                  VARCHAR2(4000);
    L_ENVELOPE             VARCHAR2(10000);
    L_RESPONSE_CLOB             CLOB;
    V_STATUSCODE                 NUMBER;
  BEGIN
        WIP_DEBUG (2, 18000, 'Inside UPDATE_PROJECT_LINES_DFF', '');
    L_URL := INSTANCE_URL
             || '/fscmRestApi/resources/11.13.18.05/projectExpenditureItems/'
             || TRIM(BOTH '-' FROM P_EXP_ID)
             || '/child/ProjectExpenditureItemsDFF/'
             || TRIM(BOTH '-' FROM P_EXP_ID);
    L_ENVELOPE := '{"internalComment" : "'
              || P_INTERNAL_COMMENT
              || '",
                "narrativeBillingOverflow1" : "'
              || P_NARRATIVE_BILLING_OVERFLOW
              || '" ,
                "event" : "'
              || P_EVENT_ATTR
              || '" ,
                "standardBillRate" : "'
              || P_STANDARD_BILL_RATE_ATTR
              || '",
                "projectBillRate" : "'
              || P_PROJECT_BILL_RATE_ATTR
              || '",
                "realizedBillRate" : "'
              || P_REALIZED_BILL_RATE_ATTR
              || '"
               }';
    WIP_DEBUG (2, 180000, L_URL, '');
    WIP_DEBUG (2, 180001, L_ENVELOPE, '');
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/json';
    L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST ( P_URL => L_URL,
                                                            P_HTTP_METHOD => 'PATCH',
                                                            P_SCHEME => 'OAUTH_CLIENT_CRED',
                                                            P_BODY => L_ENVELOPE );
    V_STATUSCODE := APEX_WEB_SERVICE.G_STATUS_CODE;
    -- APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE ();
    WIP_DEBUG (2, 180002, '', L_RESPONSE_CLOB);
    WIP_DEBUG (2, 180003, V_STATUSCODE, '');
    RETURN V_STATUSCODE;
  END;
  PROCEDURE UPDATE_STATUS (
    P_PROJECT_NUMBER IN VARCHAR2 DEFAULT NULL,
    P_AGREEMENT_NUMBER IN VARCHAR2 DEFAULT NULL,
    P_UNBILLED_FLAG IN VARCHAR2,
    P_BILL_THRU_DATE IN DATE,
    P_JWT IN VARCHAR2,
    P_BILL_FROM_DATE IN DATE DEFAULT TO_DATE('01-01-1997', 'MM-DD-YYYY')
  ) IS
    L_URL                  VARCHAR2(4000);
    L_VERSION              VARCHAR2(1000) := '1.2';
    L_ENVELOPE             VARCHAR2(10000);
    L_XML_RESPONSE         XMLTYPE;
    L_CLOB_REPORT_RESPONSE CLOB;
    L_CLOB_REPORT_DECODE   CLOB;
    L_CLOB_TEMP            CLOB;
    L_OTBI_FLAG            VARCHAR2(1) := 'N';
    V_CONTRACT_ID          NUMBER;
  BEGIN
    IF P_URL IS NULL THEN
      P_URL := INSTANCE_URL
               || '/xmlpserver/services/ExternalReportWSSService';
    END IF;
    L_URL := P_URL;
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_RESPONSE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_DECODE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_TEMP, TRUE);
 --- Code for Project Costs
    DELETE FROM XXGPMS_PROJECT_COSTS
    WHERE
      SESSION_ID = V ('APP_SESSION');
    DELETE FROM XXGPMS_PROJECT_EVENTS
    WHERE
      SESSION_ID = V ('APP_SESSION');
    DELETE FROM XXGPMS_PROJECT_CONTRACT
    WHERE
      SESSION_ID = V ('APP_SESSION');
    DELETE FROM XXGPMS_PROJECT_SPLIT
    WHERE
      SESSION_ID = V ('APP_SESSION');
    DELETE FROM XXGPMS_PROJECT_RATES
    WHERE
      SESSION_ID = V ('APP_SESSION');
    DELETE FROM XXGPMS_PROJECT_INVOICE_HISTORY
    WHERE
      SESSION_ID = V ('APP_SESSION');
    DELETE FROM XXGPMS_MATTER_CREDITS
    WHERE
      SESSION_ID = V ('APP_SESSION');
        DELETE FROM XXGPMS_INTERPROJECTS
    WHERE
      SESSION_ID = V ('APP_SESSION');
    DELETE FROM XXGPMS_EXP_TYPES;
    DELETE FROM AXXML_TAB
    WHERE
      SESSION_ID = V ('APP_SESSION');
    WIP_DEBUG ( 1, 1000, 'Start Project Number'
                         || P_PROJECT_NUMBER
                         || '-'
                         || P_UNBILLED_FLAG
                         ||' Instance '
                         || INSTANCE_URL
                         || 'Bill From Date'
                         || P_BILL_FROM_DATE
                         || 'Bill Thru Date'
                         || P_BILL_THRU_DATE, '' );
    WIP_DEBUG (1, 1001, 'JWT '
                        || P_JWT, '');
    IF P_JWT = 'OTBI' THEN
      L_OTBI_FLAG := 'Y';
    END IF;
    L_ENVELOPE := '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">
			<soap:Header/>
			   <soap:Body>
				  <pub:runReport>
					 <pub:reportRequest>
					   <pub:attributeFormat>xml</pub:attributeFormat>
						 <pub:parameterNameValues>
							<pub:item>
								<pub:name>P_Proj_Number</pub:name>
								<pub:values>
									<pub:item>'
                  || P_PROJECT_NUMBER
                  || '</pub:item>
								</pub:values>
							</pub:item>
							<pub:item>
								<pub:name>P_Agreement_Number</pub:name>
								<pub:values>
									<pub:item>'
                  || P_AGREEMENT_NUMBER
                  || '</pub:item>
								</pub:values>
							</pub:item>
							<pub:item>
								<pub:name>P_Unbilled_Flag</pub:name>
								<pub:values>
									<pub:item>'
                  || P_UNBILLED_FLAG
                  || '</pub:item>
								</pub:values>
							</pub:item>
							<pub:item>
								<pub:name>P_Bill_Thru_Date</pub:name>
								<pub:values>
									<pub:item>'
                  || TO_CHAR(P_BILL_THRU_DATE, 'MM-DD-YYYY')
                     || '</pub:item>
								</pub:values>
							</pub:item>
                            <pub:item>
								<pub:name>P_Bill_From_Date</pub:name>
								<pub:values>
									<pub:item>'
                     || TO_CHAR(P_BILL_FROM_DATE, 'MM-DD-YYYY')
                        || '</pub:item>
								</pub:values>
							</pub:item>
						</pub:parameterNameValues>
					   <pub:reportAbsolutePath>/Custom/Projects/Project Billing/Project Costs Report.xdo</pub:reportAbsolutePath>
					   <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
					 </pub:reportRequest>
					 <pub:appParams></pub:appParams>
				  </pub:runReport>
			   </soap:Body>
			</soap:Envelope>';
    WIP_DEBUG (2, 10481, '', L_ENVELOPE);
    WIP_DEBUG (2, 10481.1, '', L_URL);
    WIP_DEBUG (2, 10481.2, '', L_OTBI_FLAG);
    IF L_OTBI_FLAG = 'N' THEN
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Authorization';
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'Bearer '
                                                      || P_JWT;
      L_XML_RESPONSE := APEX_WEB_SERVICE.MAKE_REQUEST (
        P_URL => L_URL,
        P_VERSION => L_VERSION,
        P_ACTION => 'runReport',
        P_ENVELOPE => L_ENVELOPE
      );
    ELSE
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Authorization';
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'Bearer '
                                                      || V ('G_SAAS_ACCESS_TOKEN');
    --   WIP_DEBUG (2, 10481.3, '', APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE);
 -- l_xml_response := apex_web_service.make_request ( p_url => l_url, p_version => l_version, p_action => 'runReport', p_envelope => l_envelope, p_username => g_username, p_password => g_password );
      BEGIN
        L_XML_RESPONSE := APEX_WEB_SERVICE.MAKE_REQUEST ( P_URL => L_URL
                  , P_VERSION => L_VERSION, P_ACTION => 'runReport'
                  , P_ENVELOPE => L_ENVELOPE
                --   ,p_username => 'amy.marlin'
                --   ,p_password => 'm9T7w^h%'
                  --    , P_CREDENTIAL_STATIC_ID => 'GPMS_DEV'
    -- , P_TOKEN_URL => v('G_SAAS_ACCESS_TOKEN'
        );
      EXCEPTION
        WHEN OTHERS THEN
          WIP_DEBUG(3, 10482.1, 'Error: '
                                ||APEX_WEB_SERVICE.G_STATUS_CODE, SQLERRM);
          WIP_DEBUG(3, 10482.2, 'URL: '
                                ||L_URL, '');
      END;
 -- L_XML_RESPONSE := APEX_WEB_SERVICE.MAKE_REQUEST(P_URL => L_URL, P_VERSION => L_VERSION, P_ACTION => 'runReport', P_ENVELOPE =>
 -- L_ENVELOPE, P_CREDENTIAL_STATIC_ID => 'GPMS_DEV');
    END IF;
    WIP_DEBUG (2, 1048, '', L_XML_RESPONSE.GETCLOBVAL ());
    L_CLOB_REPORT_RESPONSE := APEX_WEB_SERVICE.PARSE_XML_CLOB ( P_XML => L_XML_RESPONSE, P_XPATH => ' //runReportResponse/runReportReturn/reportBytes', P_NS => ' xmlns="http://xmlns.oracle.com/oxp/service/PublicReportService"' );
    WIP_DEBUG (2, 1049, '', L_CLOB_REPORT_RESPONSE);
 -- now we need to do the following substr on the clob instead
    L_CLOB_TEMP := SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1, INSTR( SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1 ), '</ns2:report' ) - 1 );
    L_CLOB_REPORT_RESPONSE := L_CLOB_TEMP;
    L_CLOB_REPORT_DECODE := BASE64_DECODE_CLOB (L_CLOB_REPORT_RESPONSE);
    WIP_DEBUG (2, 1050, '', L_CLOB_REPORT_DECODE);
    COMMIT;
    INSERT INTO XXGPMS_PROJECT_COSTS (
      PROJECT_ID,
      EXPENDITURE_ITEM_ID,
      PROJECT_NUMBER,
      BILLABLE_FLAG,
      TASK_ID,
      TASK_NUMBER,
      TOP_TASK_NUMBER,
      PROJECT_STATUS_CODE,
      PROJECT_NAME,
      EXPENDITURE_ITEM_DATE,
      REVENUE_RECOGNIZED_FLAG,
      BILL_HOLD_FLAG,
      QUANTITY,
      PROJFUNC_RAW_COST,
      RAW_COST_RATE,
      PROJFUNC_BURDENED_COST,
      BURDEN_COST_RATE,
      INVOICED_FLAG,
      REVENUE_HOLD_FLAG,
      ACCT_CURRENCY_CODE,
      ACCT_RAW_COST,
      ACCT_BURDENED_COST,
      TASK_BILLABLE_FLAG,
      EXTERNAL_BILL_RATE,
      TOTAL_AMOUNT,
      INTERNAL_COMMENT,
      NARRATIVE_BILLING_OVERFLOW,
      TASK_START_DATE,
      TASK_COMPLETION_DATE,
      PROJECT_START_DATE,
      TASK_NAME,
      EXPENDITURE_COMMENT,
      UNIT_OF_MEASURE,
      FIRST_NAME,
      LAST_NAME,
      PERSON_NAME,
      EXPENDITURE_TYPE_NAME,
      EXPENDITURE_CATEGORY_NAME,
      STANDARD_BILL_RATE_ATTR,
      STANDARD_BILL_RATE_AMT,
      PROJECT_BILL_RATE_ATTR,
      PROJECT_BILL_RATE_AMT,
      REALIZED_BILL_RATE_ATTR,
      REALIZED_BILL_RATE_AMT,
      EVENT_ATTR,
      BU_NAME,
      BU_ID,
      JOB_NAME,
      JOB_ID,
      SYSTEM_LINKAGE_FUNCTION,
      ORIG_TRANSACTION_REFERENCE,
      DOCUMENT_NAME,
      DOC_ENTRY_NAME,
      CST_INVOICE_SUBMITTED_COUNT,
      CREATION_DATE,
      SESSION_ID,
      CONTRACT_NUMBER,
      LINE_NUMBER,
      BILLING_INSTRUCTIONS,
      DRAFT_INVOICE_NUMBER,
      INVOICE_STATUS_CODE,
      TRANSFER_STATUS_CODE,
      NLR_ORG_ID,
      WIP_CATEGORY,
      NON_LABOUR_RESOURCE_NAME,
      PROJECT_CURRENCY_CODE,
      WRITE_UP_DOWN_VALUE,
      INCURRED_BY_PERSON_ID,
      JOB_APPROVAL_ID,
      DESCRIPTION,
      BILL_SET_NUM,
      CONTRACT_LINE_NUM,
      EXP_BU_ID,
      EXP_ORG_ID,
      DEPT_NAME,
      TRANSACTION_SOURCE,
      TRANSACTION_SOURCE_ID,
      DOCUMENT_ID
    )
      SELECT
        PROJECT_ID,
        EXPENDITURE_ITEM_ID,
        PROJECT_NUMBER,
        BILLABLE_FLAG,
        TASK_ID,
        TASK_NUMBER,
        TOP_TASK_NUMBER,
        PROJECT_STATUS_CODE,
        PROJECT_NAME,
        EXPENDITURE_ITEM_DATE,
        REVENUE_RECOGNIZED_FLAG,
        BILL_HOLD_FLAG,
        QUANTITY,
        PROJFUNC_RAW_COST,
        RAW_COST_RATE,
        PROJFUNC_BURDENED_COST,
        BURDEN_COST_RATE,
        INVOICED_FLAG,
        REVENUE_HOLD_FLAG,
        ACCT_CURRENCY_CODE,
        ACCT_RAW_COST,
        ACCT_BURDENED_COST,
        TASK_BILLABLE_FLAG,
        EXTERNAL_BILL_RATE,
        ROUND(NVL(EXTERNAL_BILL_RATE, 0) * QUANTITY, 2),
        INTERNAL_COMMENT,
        NARRATIVE_BILLING_OVERFLOW,
        TASK_START_DATE,
        TASK_COMPLETION_DATE,
        PROJECT_START_DATE,
        TASK_NAME,
        EXPENDITURE_COMMENT,
        UNIT_OF_MEASURE,
        FIRST_NAME,
        LAST_NAME,
        FIRST_NAME
        || ' '
        || LAST_NAME,
        EXPENDITURE_TYPE_NAME,
        EXPENDITURE_CATEGORY_NAME,
        TO_CHAR(STANDARD_BILL_RATE_ATTR, '9999999990.00'),
        TO_CHAR( (STANDARD_BILL_RATE_ATTR * QUANTITY), '9999999990.00' ),
        TO_CHAR(PROJECT_BILL_RATE_ATTR, '9999999990.00'),
        TO_CHAR( (PROJECT_BILL_RATE_ATTR * QUANTITY), '9999999990.00' ),
        TO_CHAR(REALIZED_BILL_RATE_ATTR, '9999999990.00'),
        TO_CHAR( (REALIZED_BILL_RATE_ATTR * QUANTITY), '9999999990.00' ),
        EVENT_ATTR,
        BU_NAME,
        BU_ID,
        JOB_NAME,
        JOB_ID,
        SYSTEM_LINKAGE_FUNCTION,
        ORIG_TRANSACTION_REFERENCE,
        DOCUMENT_NAME,
        DOC_ENTRY_NAME,
        CST_INVOICE_SUBMITTED_COUNT,
        SYSDATE,
        V ('APP_SESSION'),
        CONTRACT_NUMBER,
        LINE_NUMBER,
        BILLING_INSTRUCTIONS,
        INVOICE_NUM,
        INVOICE_STATUS_CODE,
        TRANSFER_STATUS_CODE,
        NON_LABOR_RESOURCE_ORG_ID,
        WIP_CATEGORY,
        NON_LABOUR_RESOURCE_NAME,
        PROJECT_CURRENCY_CODE,
        WRITE_UP_DOWN_VALUE,
        INCURRED_BY_PERSON_ID,
        JOB_APPROVAL_ID,
        DESCRIPTION,
        BILL_SET_NUM,
        CONTRACT_LINE_NUM,
        EXP_BU_ID,
        EXP_ORG_ID,
        DEPT_NAME,
        TRANSACTION_SOURCE,
        TRANSACTION_SOURCE_ID,
        DOCUMENT_ID
      FROM
        XMLTABLE( '/DATA_DS/G_PROJECT_COST' PASSING XMLTYPE (L_CLOB_REPORT_DECODE) COLUMNS PROJECT_ID PATH 'PROJECT_ID',
        EXPENDITURE_ITEM_ID PATH 'EXPENDITURE_ITEM_ID',
        PROJECT_NUMBER PATH 'PROJECT_NUMBER',
        BILLABLE_FLAG PATH 'BILLABLE_FLAG',
        TASK_ID PATH 'TASK_ID',
        TASK_NUMBER PATH 'TASK_NUMBER',
        TOP_TASK_NUMBER PATH 'TOP_TASK_NUMBER',
        PROJECT_STATUS_CODE PATH 'PROJECT_STATUS_CODE',
        PROJECT_NAME PATH 'PROJECT_NAME',
        EXPENDITURE_ITEM_DATE PATH 'EXPENDITURE_ITEM_DATE',
        REVENUE_RECOGNIZED_FLAG PATH 'REVENUE_RECOGNIZED_FLAG',
        BILL_HOLD_FLAG PATH 'BILL_HOLD_FLAG',
        QUANTITY PATH 'QUANTITY',
        PROJFUNC_RAW_COST PATH 'PROJFUNC_RAW_COST',
        RAW_COST_RATE PATH 'RAW_COST_RATE',
        PROJFUNC_BURDENED_COST PATH 'PROJFUNC_BURDENED_COST',
        BURDEN_COST_RATE PATH 'BURDEN_COST_RATE',
        INVOICED_FLAG PATH 'INVOICED_FLAG',
        REVENUE_HOLD_FLAG PATH 'REVENUE_HOLD_FLAG',
        ACCT_CURRENCY_CODE PATH 'ACCT_CURRENCY_CODE',
        ACCT_RAW_COST PATH 'ACCT_RAW_COST',
        ACCT_BURDENED_COST PATH 'ACCT_BURDENED_COST',
        TASK_BILLABLE_FLAG PATH 'TASK_BILLABLE_FLAG',
        EXTERNAL_BILL_RATE PATH 'EXTERNAL_BILL_RATE',
        INTERNAL_COMMENT PATH 'INTERNALCOMMENT',
        NARRATIVE_BILLING_OVERFLOW PATH 'NARRATIVEBILLINGOVERFLOW',
        TASK_START_DATE PATH 'TASK_START_DATE',
        TASK_COMPLETION_DATE PATH 'TASK_COMPLETION_DATE',
        PROJECT_START_DATE PATH 'PROJECT_START_DATE',
        TASK_NAME PATH 'TASK_NAME',
        EXPENDITURE_COMMENT PATH 'EXPENDITURE_COMMENT',
        UNIT_OF_MEASURE PATH 'UNIT_OF_MEASURE',
        FIRST_NAME PATH 'FIRST_NAME',
        LAST_NAME PATH 'LAST_NAME',
        EXPENDITURE_TYPE_NAME PATH 'EXPENDITURE_TYPE_NAME',
        EXPENDITURE_CATEGORY_NAME PATH 'EXPENDITURE_CATEGORY_NAME',
        STANDARD_BILL_RATE_ATTR PATH 'ATTRSTDBILLRATE',
        PROJECT_BILL_RATE_ATTR PATH 'ATTRPRJBILLRATE',
        REALIZED_BILL_RATE_ATTR PATH 'ATTRRLZBILLRATE',
        EVENT_ATTR PATH 'ATTREVENT',
        BU_NAME PATH 'BU_NAME',
        BU_ID PATH 'BU_ID',
        JOB_NAME PATH 'JOB_NAME',
        JOB_ID PATH 'JOB_ID',
        SYSTEM_LINKAGE_FUNCTION PATH 'SYSTEM_LINKAGE_FUNCTION',
        ORIG_TRANSACTION_REFERENCE PATH 'ORIG_TRANSACTION_REFERENCE',
        DOCUMENT_NAME PATH 'DOCUMENT_NAME',
        DOC_ENTRY_NAME PATH 'DOC_ENTRY_NAME',
        CST_INVOICE_SUBMITTED_COUNT PATH 'CST_INVOICE_SUBMITTED_COUNT',
        CONTRACT_NUMBER PATH 'CONTRACT_NUMBER',
        LINE_NUMBER PATH 'LINE_NUMBER',
        BILLING_INSTRUCTIONS PATH 'BILLING_INSTRUCTIONS',
        INVOICE_NUM PATH 'INVOICE_NUM',
        INVOICE_STATUS_CODE PATH 'INVOICE_STATUS_CODE',
        TRANSFER_STATUS_CODE PATH 'TRANSFER_STATUS_CODE',
        NON_LABOR_RESOURCE_ORG_ID PATH 'NON_LABOR_RESOURCE_ORG_ID',
        WIP_CATEGORY PATH 'WIP_CATEGORY',
        NON_LABOUR_RESOURCE_NAME PATH 'NON_LABOUR_RESOURCE_NAME',
        PROJECT_CURRENCY_CODE PATH 'PROJECT_CURRENCY_CODE',
        WRITE_UP_DOWN_VALUE PATH 'WRITE_UP_DOWN_VALUE',
        INCURRED_BY_PERSON_ID PATH 'INCURRED_BY_PERSON_ID',
        JOB_APPROVAL_ID PATH 'JOB_APPROVAL_ID',
        DESCRIPTION PATH 'DESCRIPTION',
        BILL_SET_NUM PATH 'BILL_SET_NUM',
        CONTRACT_LINE_NUM PATH 'CONTRACT_LINE_NUM',
        EXP_BU_ID PATH 'EXP_BU_ID',
        EXP_ORG_ID PATH 'EXP_ORG_ID' ,
        DEPT_NAME PATH 'DEPT_NAME',
        TRANSACTION_SOURCE PATH 'TRANSACTION_SOURCE',
        TRANSACTION_SOURCE_ID PATH 'TRANSACTION_SOURCE_ID',
        DOCUMENT_ID PATH 'DOCUMENT_ID'
        )                    XT;
    WIP_DEBUG (2, 1051, '', 'Inserted into Project Costs');
 -- WIP CATEGORY
    INSERT INTO XXGPMS_PROJECT_WIP_CATEGORY (
      WIP_CATEGORY,
      SESSION_ID,
      DRAFT_NUMBER,
      PROJECT_NUMBER,
      AGREEMENT_NUMBER
    )
      SELECT
        WIP_CATEGORY,
        SESSION_ID,
        NULL,
        PROJECT_NUMBER,
        CONTRACT_NUMBER
      FROM
        XXGPMS_PROJECT_COSTS
      WHERE
        SESSION_ID = V ('APP_SESSION');
    INSERT INTO XXGPMS_PROJECT_CONTRACT (
      PROJECT_ID,
      PROJECT_NUMBER,
      PROJECT_NAME,
      LEGAL_ENTITY_NAME,
      CONTRACT_NUMBER,
      CONTRACT_ID,
      BU_NAME,
      ORGANIZATION_NAME,
      CURRENCY_CODE,
      CONTRACT_TYPE_NAME,
      CUSTOMER_NAME,
      RETAINER_BALANCE,
      TRUST_BALANCE,
      BUSINESS_UNIT_ID,
      TRANSACTION_SOURCE_ID,
      USER_TRANSACTION_SOURCE,
      SESSION_ID,
      CONTRACT_TYPE_ID,
      EBILL_MATTER_ID,
      TAX_REGISTRATION_TYPE,
      TAX_REGISTRATION_NUMBER,
      TAX_REGISTRATION_COUNTRY,
      CONTRACT_OFFICE,
      BILL_CUSTOMER_NAME,
      BILL_CUSTOMER_ACCT,
      BILL_CUSTOMER_SITE,
      CLIENT_NUMBER
    )
      SELECT
        PROJECT_ID,
        PROJECT_NUMBER,
        PROJECT_NAME,
        LEGAL_ENTITY_NAME,
        CONTRACT_NUMBER,
        CONTRACT_ID,
        BU_NAME,
        ORGANIZATION_NAME,
        CURRENCY_CODE,
        CONTRACT_TYPE_NAME,
        CUSTOMER_NAME,
        RETAINER_BALANCE,
        TRUST_BALANCE,
        BUSINESS_UNIT_ID,
        TRANSACTION_SOURCE_ID,
        USER_TRANSACTION_SOURCE,
        V ('APP_SESSION'),
        CONTRACT_TYPE_ID,
        EBILL_MATTER_ID,
        TAX_REGISTRATION_TYPE,
        TAX_REGISTRATION_NUMBER,
        TAX_REGISTRATION_COUNTRY,
        CONTRACT_OFFICE,
        BILL_CUSTOMER_NAME,
        BILL_CUSTOMER_ACCT,
        BILL_CUSTOMER_SITE,
        CLIENT_NUMBER
      FROM
        XMLTABLE( '/DATA_DS/G_PROJECT_CONTRACTS' PASSING XMLTYPE (L_CLOB_REPORT_DECODE) COLUMNS PROJECT_ID PATH 'PROJECT_ID',
        PROJECT_NUMBER PATH 'PROJECT_NUMBER',
        PROJECT_NAME PATH 'PROJECT_NAME',
        LEGAL_ENTITY_NAME PATH 'LEGAL_ENTITY_NAME',
        CONTRACT_NUMBER PATH 'CONTRACT_NUMBER',
        CONTRACT_ID PATH 'CONTRACT_ID',
        BU_NAME PATH 'BU_NAME',
        ORGANIZATION_NAME PATH 'ORGANIZATION_NAME',
        CURRENCY_CODE PATH 'CURRENCY_CODE',
        CONTRACT_TYPE_NAME PATH 'CONTRACT_TYPE_NAME',
        CUSTOMER_NAME PATH 'CUSTOMER_NAME',
        RETAINER_BALANCE PATH 'RETAINER_BALANCE',
        TRUST_BALANCE PATH 'TRUST_BALANCE',
        BUSINESS_UNIT_ID PATH 'BUSINESS_UNIT_ID',
        TRANSACTION_SOURCE_ID PATH 'TRANSACTION_SOURCE_ID',
        USER_TRANSACTION_SOURCE PATH 'USER_TRANSACTION_SOURCE',
        CONTRACT_TYPE_ID PATH 'CONTRACT_TYPE_ID',
        EBILL_MATTER_ID PATH 'ATTRIBUTE4',
        TAX_REGISTRATION_TYPE PATH 'TAX_REGISTRATION_TYPE',
        TAX_REGISTRATION_NUMBER PATH 'TAX_REGISTRATION_NUMBER',
        TAX_REGISTRATION_COUNTRY PATH 'TAX_REGISTRATION_COUNTRY',
        CONTRACT_OFFICE PATH 'ATTRIBUTE16',
        BILL_CUSTOMER_NAME PATH 'BILL_CUSTOMER_NAME',
        BILL_CUSTOMER_ACCT PATH 'BILL_CUST_ACCT_NAME',
        BILL_CUSTOMER_SITE PATH 'BILL_CUST_SITE',
        CLIENT_NUMBER PATH 'PARTY_NUMBER' )                    XT;
    DBMS_LOB.FREETEMPORARY (L_CLOB_REPORT_RESPONSE);
    DBMS_LOB.FREETEMPORARY (L_CLOB_REPORT_DECODE);
    DBMS_LOB.FREETEMPORARY (L_CLOB_TEMP);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_RESPONSE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_DECODE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_TEMP, TRUE);
    WIP_DEBUG (3, 1055, 'Project Costs - Completed', '');
 --- Code for Project Events
    L_ENVELOPE := '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">
			<soap:Header/>
			   <soap:Body>
				  <pub:runReport>
					 <pub:reportRequest>
					   <pub:attributeFormat>xml</pub:attributeFormat>
						 <pub:parameterNameValues>
							<pub:item>
								<pub:name>P_Proj_Number</pub:name>
								<pub:values>
									<pub:item>'
                  || P_PROJECT_NUMBER
                  || '</pub:item>
								</pub:values>
							</pub:item>
							<pub:item>
								<pub:name>P_Agreement_Number</pub:name>
								<pub:values>
									<pub:item>'
                  || P_AGREEMENT_NUMBER
                  || '</pub:item>
								</pub:values>
							</pub:item>
							<pub:item>
								<pub:name>P_Unbilled_Flag</pub:name>
								<pub:values>
									<pub:item>'
                  || P_UNBILLED_FLAG
                  || '</pub:item>
								</pub:values>
							</pub:item>
							<pub:item>
								<pub:name>P_Bill_Thru_Date</pub:name>
								<pub:values>
									<pub:item>'
                  || TO_CHAR(P_BILL_THRU_DATE, 'MM-DD-YYYY')
                     || '</pub:item>
								</pub:values>
							</pub:item>
						</pub:parameterNameValues>
					   <pub:reportAbsolutePath>/Custom/Projects/Project Billing/Project Events Report.xdo</pub:reportAbsolutePath>
					   <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
					 </pub:reportRequest>
					 <pub:appParams></pub:appParams>
				  </pub:runReport>
			   </soap:Body>
			</soap:Envelope>';
    WIP_DEBUG (2, 1056, '', L_ENVELOPE);
    IF L_OTBI_FLAG = 'N' THEN
      L_XML_RESPONSE := APEX_WEB_SERVICE.MAKE_REQUEST (
        P_URL => L_URL,
        P_VERSION => L_VERSION,
        P_ACTION => 'runReport',
        P_ENVELOPE => L_ENVELOPE
      );
    ELSE --l_xml_response := apex_web_service.make_request ( p_url => l_url, p_version => l_version, p_action => 'runReport', p_envelope => l_envelope, p_username => g_username, p_password => g_password );
      L_XML_RESPONSE := APEX_WEB_SERVICE.MAKE_REQUEST (
        P_URL => L_URL,
        P_VERSION => L_VERSION,
        P_ACTION => 'runReport',
        P_ENVELOPE => L_ENVELOPE --, P_CREDENTIAL_STATIC_ID => 'GPMS_DEV'
      );
    END IF;
 -- WIP_DEBUG (2, 1059,L_XML_RESPONSE.GETCLOBVAL(),'');
    L_CLOB_REPORT_RESPONSE := APEX_WEB_SERVICE.PARSE_XML_CLOB ( P_XML => L_XML_RESPONSE, P_XPATH => ' //runReportResponse/runReportReturn/reportBytes', P_NS => ' xmlns="http://xmlns.oracle.com/oxp/service/PublicReportService"' );
    L_CLOB_TEMP := SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1, INSTR( SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1 ), '</ns2:report' ) - 1 );
    L_CLOB_REPORT_RESPONSE := L_CLOB_TEMP;
    L_CLOB_REPORT_DECODE := BASE64_DECODE_CLOB (L_CLOB_REPORT_RESPONSE);
    WIP_DEBUG (2, 1060, '', L_CLOB_REPORT_DECODE);
    INSERT INTO XXGPMS_PROJECT_EVENTS (
      PROJECT_ID,
      PROJECT_NUMBER,
      PROJECT_STATUS_CODE,
      PROJECT_NAME,
      EVENT_ID,
      EVENT_NUM,
      EVENT_DESC,
      EVENT_TYPE_CODE,
      BILL_TRNS_AMOUNT,
      BILL_TRNS_CURRENCY_CODE,
      BILL_HOLD_FLAG,
      REVENUE_HOLD_FLAG,
      INVOICE_CURRENCY_CODE,
      TASK_BILLABLE_FLAG,
      TASK_START_DATE,
      TASK_COMPLETION_DATE,
      TASK_NUMBER,
      INVOICEDSTATUS,
      PROJECT_START_DATE,
      EVNT_COMPLETION_DATE,
      EVENT_INTERNAL_COMMENT,
      CONTRACT_NUMBER,
      CONTRACT_LINE_NUMBER,
      FUSION_FLAG,
      EVNT_INVOICE_SUBMITTED_COUNT,
      WIP_EVENT_TAG,
      SESSION_ID,
      DRAFT_INVOICE_NUMBER,
      INVOICE_STATUS_CODE,
      TRANSFER_STATUS_CODE,
      WIP_CATEGORY,
      EXPENDITURE_TYPE,
      BILL_SET_NUM,
      EVENT_TYPE_NAME,
      TASK_NAME
    )
      SELECT
        PROJECT_ID,
        PROJECT_NUMBER,
        PROJECT_STATUS_CODE,
        PROJECT_NAME,
        EVENT_ID,
        EVENT_NUM,
        EVENT_DESC,
        EVENT_TYPE_CODE,
        BILL_TRNS_AMOUNT,
        BILL_TRNS_CURRENCY_CODE,
        BILL_HOLD_FLAG,
        REVENUE_HOLD_FLAG,
        INVOICE_CURRENCY_CODE,
        TASK_BILLABLE_FLAG,
        TASK_START_DATE,
        TASK_COMPLETION_DATE,
        TASK_NUMBER,
        INVOICEDSTATUS,
        PROJECT_START_DATE,
        EVNT_COMPLETION_DATE,
        EVENT_INTERNAL_COMMENT,
        CONTRACT_NUMBER,
        CONTRACT_LINE_NUMBER,
        'Y',
        EVNT_INVOICE_SUBMITTED_COUNT,
        WIP_EVENT_TAG,
        V ('APP_SESSION'),
        INVOICE_NUM,
        INVOICE_STATUS_CODE,
        TRANSFER_STATUS_CODE,
        WIP_CATEGORY,
        EXPENDITURE_TYPE,
        BILL_SET_NUM,
        EVENT_TYPE_NAME,
        TASK_NAME
      FROM
        XMLTABLE( '/DATA_DS/G_PROJECT_EVENTS' PASSING XMLTYPE (L_CLOB_REPORT_DECODE) COLUMNS PROJECT_ID PATH 'PROJECT_ID',
        PROJECT_NUMBER PATH 'SEGMENT1',
        PROJECT_STATUS_CODE PATH 'PROJECT_STATUS_CODE',
        PROJECT_NAME PATH 'PROJECT_NAME',
        EVENT_ID PATH 'EVENT_ID',
        EVENT_NUM PATH 'EVENT_NUM',
        EVENT_DESC PATH 'EVENT_DESC',
        EVENT_TYPE_CODE PATH 'EVENT_TYPE_CODE',
        BILL_TRNS_AMOUNT PATH 'BILL_TRNS_AMOUNT',
        BILL_TRNS_CURRENCY_CODE PATH 'BILL_TRNS_CURRENCY_CODE',
        BILL_HOLD_FLAG PATH 'BILL_HOLD_FLAG',
        REVENUE_HOLD_FLAG PATH 'REVENUE_HOLD_FLAG',
        INVOICE_CURRENCY_CODE PATH 'INVOICE_CURRENCY_CODE',
        TASK_BILLABLE_FLAG PATH 'TASK_BILLABLE_FLAG',
        TASK_START_DATE PATH 'TASK_START_DATE',
        TASK_COMPLETION_DATE PATH 'TASK_COMPLETION_DATE',
        TASK_NUMBER PATH 'TASK_NUMBER',
        INVOICEDSTATUS PATH 'INVOICEDSTATUS',
        PROJECT_START_DATE PATH 'PROJECT_START_DATE',
        EVNT_COMPLETION_DATE PATH 'EVNT_COMPLETION_DATE',
        EVENT_INTERNAL_COMMENT PATH 'EVENT_INTERNAL_COMMENT',
        CONTRACT_NUMBER PATH 'CONTRACT_NUMBER',
        CONTRACT_LINE_NUMBER PATH 'CONTRACT_LINE_NUMBER',
        EVNT_INVOICE_SUBMITTED_COUNT PATH 'EVNT_INVOICE_SUBMITTED_COUNT',
        WIP_EVENT_TAG PATH 'WIP_EVENT_TAG',
        INVOICE_NUM PATH 'INVOICE_NUM',
        INVOICE_STATUS_CODE PATH 'INVOICE_STATUS_CODE',
        TRANSFER_STATUS_CODE PATH 'TRANSFER_STATUS_CODE',
        WIP_CATEGORY PATH 'ATTRIBUTE2',
        EXPENDITURE_TYPE PATH 'ATTRIBUTE3',
        BILL_SET_NUM PATH 'BILL_SET_NUM',
        EVENT_TYPE_NAME PATH 'EVENT_TYPE_NAME',
        TASK_NAME PATH 'TASK_NAME' )                    XT;
    DBMS_LOB.FREETEMPORARY (L_CLOB_REPORT_RESPONSE);
    DBMS_LOB.FREETEMPORARY (L_CLOB_REPORT_DECODE);
    DBMS_LOB.FREETEMPORARY (L_CLOB_TEMP);
    APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE ();
    WIP_DEBUG (1, 1070, 'Getting Invoice History', '');
    SELECT
      CONTRACT_ID INTO V_CONTRACT_ID
    FROM
      XXGPMS_PROJECT_CONTRACT
    WHERE
      PROJECT_NUMBER = NVL(P_PROJECT_NUMBER, PROJECT_NUMBER)
      AND CONTRACT_NUMBER = NVL(P_AGREEMENT_NUMBER, CONTRACT_NUMBER)
      AND SESSION_ID = V ('APP_SESSION')
      AND ROWNUM = 1;
    WIP_DEBUG (1, 1071, 'Contract ID: '
                        ||V_CONTRACT_ID, '');
    GET_INVOICE_HISTORY(V_CONTRACT_ID);
    GET_MATTER_CREDITS(V_CONTRACT_ID);
    GET_INTERPROJECTS(V_CONTRACT_ID);
    WIP_DEBUG (1, 1100, 'End of XX_GPMS.UPDATE_STATUS', '');
  EXCEPTION
    WHEN OTHERS THEN -- raise_application_error(-20111,'Credentials Error!');
      WIP_DEBUG (1, 1999, DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, '');
  END UPDATE_STATUS;
  PROCEDURE PROCESS_BILL_OVERRIDE (
    P_EXPENDITURE_ITEM_ID IN VARCHAR2,
    P_PROJECT_NUMBER IN VARCHAR2
  ) IS
    L_URL                        VARCHAR2(4000);
    L_VERSION                    VARCHAR2(10);
    L_RESPONSE_CLOB              CLOB;
    L_ENVELOPE                   VARCHAR2(32000);
    P_EXP_AMT                    NUMBER;
    P_INTERNAL_COMMENT           VARCHAR2(1000);
    P_NARRATIVE_BILLING_OVERFLOW VARCHAR2(1000);
    P_EVENT_ATTR                 VARCHAR2(50);
    P_STANDARD_BILL_RATE_ATTR    NUMBER;
    P_PROJECT_BILL_RATE_ATTR     NUMBER;
    P_REALIZED_BILL_RATE_ATTR    NUMBER;
    P_BILLABLE_FLAG              VARCHAR2(10);
    V_STATUSCODE                 NUMBER;
    P_BILL_HOLD_FLAG             VARCHAR2(100);
  BEGIN
    WIP_DEBUG (3, 3000, 'Process Bill Override: ', '');
    L_VERSION := '1.2';
    SELECT
      EXTERNAL_BILL_RATE,
      REPLACE(INTERNAL_COMMENT, CHR(10), '\n'),
      REPLACE(NARRATIVE_BILLING_OVERFLOW, CHR(10), '\n'),
      EVENT_ATTR,
      STANDARD_BILL_RATE_ATTR,
      PROJECT_BILL_RATE_ATTR,
      REALIZED_BILL_RATE_ATTR,
      BILLABLE_FLAG,
      DECODE(BILL_HOLD_FLAG,'O','ONE_TIME_HOLD','Y','BILL_HOLD','N','REMOVE_BILL_HOLD')
       INTO P_EXP_AMT,
      P_INTERNAL_COMMENT,
      P_NARRATIVE_BILLING_OVERFLOW,
      P_EVENT_ATTR,
      P_STANDARD_BILL_RATE_ATTR,
      P_PROJECT_BILL_RATE_ATTR,
      P_REALIZED_BILL_RATE_ATTR,
      P_BILLABLE_FLAG,
      P_BILL_HOLD_FLAG
    FROM
      XXGPMS_PROJECT_COSTS
    WHERE
      EXPENDITURE_ITEM_ID = P_EXPENDITURE_ITEM_ID
      AND SESSION_ID = V ('APP_SESSION')
      AND PROJECT_NUMBER = nvl(P_PROJECT_NUMBER,PROJECT_NUMBER)
      AND ROWNUM <2;
 --- Update External Bill Rate -------
 -- L_URL := INSTANCE_URL
 --          || '/fscmRestApi/resources/11.13.18.05/projectExpenditureItems/'
 --          || P_EXPENDITURE_ITEM_ID;
 -- L_ENVELOPE := '{"ExternalBillRate" : "'
 --               || TO_CHAR(P_EXP_AMT)
 --               || '",
 --             "ExternalBillRateCurrency" :   "USD",
 --             "ExternalBillRateSourceName" : "PEI_REST",
 --             "ExternalBillRateSourceReference" : "abc"}';
 -- APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).NAME := 'Content-Type';
 -- APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).VALUE := 'application/json';
 -- WIP_DEBUG(3, 3025, L_ENVELOPE, '');
 -- L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST(P_URL => L_URL, P_HTTP_METHOD => 'PATCH',
 -- 					--	p_username => g_username,
 -- 					--	p_password => g_password,
 --  P_CREDENTIAL_STATIC_ID => 'GPMS_DEV', P_BODY => L_ENVELOPE);
 -- APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE();
 -- WIP_DEBUG(2, 3050, '', L_RESPONSE_CLOB);
 ---Update Billable Flag ------
    L_URL := INSTANCE_URL
             || '/fscmRestApi/resources/11.13.18.05/projectCosts/'
             || P_EXPENDITURE_ITEM_ID
             || '/action/adjustProjectCosts';
    IF P_BILLABLE_FLAG = 'Y' THEN
      L_ENVELOPE := '{"AdjustmentType" : "Set to Billable"}';
    ELSE
      L_ENVELOPE := '{"AdjustmentType" : "Set to nonbillable"}';
    END IF;
    WIP_DEBUG (2, 3008, '', L_URL);
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/vnd.oracle.adf.action+json';
    L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST ( P_URL => L_URL, P_HTTP_METHOD => 'POST',
 --p_username => g_username,
 --p_password => g_password,
 -- P_CREDENTIAL_STATIC_ID => 'GPMS_DEV'
    P_BODY => L_ENVELOPE, P_SCHEME => 'OAUTH_CLIENT_CRED');
    APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE ();
    WIP_DEBUG (2, 3100, '', L_RESPONSE_CLOB);
 ---- Update Billable Flag Done --------
    L_URL := INSTANCE_URL
             || '/fscmRestApi/resources/11.13.18.05/projectExpenditureItems/'
             || P_EXPENDITURE_ITEM_ID
             || '/child/ProjectExpenditureItemsDFF/'
             || P_EXPENDITURE_ITEM_ID;
    L_ENVELOPE := '{"internalComment" : "'
                  || P_INTERNAL_COMMENT
                  || '",
                    "narrativeBillingOverflow1" : "'
                  || P_NARRATIVE_BILLING_OVERFLOW
                  || '" ,
                    "event" : "'
                  || P_EVENT_ATTR
                  || '" ,
                    "standardBillRate" : "'
                  || P_STANDARD_BILL_RATE_ATTR
                  || '",
                    "projectBillRate" : "'
                  || P_PROJECT_BILL_RATE_ATTR
                  || '",
                    "realizedBillRate" : "'
                  || P_REALIZED_BILL_RATE_ATTR
                  || '"
                   }';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/json';
    L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST ( P_URL => L_URL, P_HTTP_METHOD => 'PATCH',
 --p_username => g_username,
 --p_password => g_password,
 -- P_CREDENTIAL_STATIC_ID => 'GPMS_DEV',
    P_SCHEME => 'OAUTH_CLIENT_CRED', P_BODY => L_ENVELOPE );
    V_STATUSCODE := APEX_WEB_SERVICE.G_STATUS_CODE;
    APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE ();
    WIP_DEBUG (2, 3200, L_URL, '');
    WIP_DEBUG (2, 3250, L_ENVELOPE, '');
    WIP_DEBUG (2, 3300, '', L_RESPONSE_CLOB);
    WIP_DEBUG (2, 3350, V_STATUSCODE, '');
  END PROCESS_BILL_OVERRIDE;
  PROCEDURE PROCESS_EVENTS_OVERRIDE (
    P_EVENT_ID IN VARCHAR2
  ) IS
    L_URL                    VARCHAR2(4000);
    L_VERSION                VARCHAR2(10);
    L_RESPONSE_CLOB          CLOB;
    L_ENVELOPE               VARCHAR2(32000);
    P_BILL_TRNS_AMOUNT       NUMBER;
    P_TASK_COMPLETION_DATE   DATE;
    P_EVENT_DESC             VARCHAR2(10000);
    P_BILL_HOLD_FLAG         VARCHAR2(1);
    P_EVENT_INTERNAL_COMMENT VARCHAR2(10000);
  BEGIN
    L_VERSION := '1.2';
    SELECT
      BILL_TRNS_AMOUNT,
      EVNT_COMPLETION_DATE,
      EVENT_DESC,
      BILL_HOLD_FLAG,
      EVENT_INTERNAL_COMMENT INTO P_BILL_TRNS_AMOUNT,
      P_TASK_COMPLETION_DATE,
      P_EVENT_DESC,
      P_BILL_HOLD_FLAG,
      P_EVENT_INTERNAL_COMMENT
    FROM
      XXGPMS_PROJECT_EVENTS
    WHERE
      EVENT_ID = P_EVENT_ID
      AND SESSION_ID = V ('APP_SESSION');
 --- Update External Bill Rate -------
    L_URL := INSTANCE_URL
             || '/fscmRestApi/resources/11.13.18.05/projectBillingEvents/'
             || P_EVENT_ID;
    L_ENVELOPE := '{"EventDescription" : "'
                  || P_EVENT_DESC
                  || '",
	        	    "BillTrnsAmount" :  '
                  || P_BILL_TRNS_AMOUNT
                  || ',
		            "BillHold" : "'
                  || P_BILL_HOLD_FLAG
                  || '"}';
 --	            "CompletionDate" : "' || to_char(p_task_completion_date,'YYYY-MM-DD') || '"}';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/json';
    L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST ( P_URL => L_URL, P_HTTP_METHOD => 'PATCH',
 --p_username => g_username,
 --p_password => g_password,
 -- P_CREDENTIAL_STATIC_ID => 'GPMS_DEV'
    P_SCHEME => 'OAUTH_CLIENT_CRED', P_BODY => L_ENVELOPE );
    APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE ();
    WIP_DEBUG (2, 3500, L_URL, '');
    WIP_DEBUG (2, 3550, L_ENVELOPE, '');
    WIP_DEBUG (2, 3560, '', L_RESPONSE_CLOB);
    L_URL := INSTANCE_URL
             || '/fscmRestApi/resources/11.13.18.05/projectBillingEvents/'
             || P_EVENT_ID
             || '/child/billingEventDFF/'
             || P_EVENT_ID;
    L_ENVELOPE := '{"internalComment" : "'
                  || P_EVENT_INTERNAL_COMMENT
                  || '"}';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/json';
    L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST ( P_URL => L_URL, P_HTTP_METHOD => 'PATCH',
 --p_username => g_username,
 --p_password => g_password,
 -- P_CREDENTIAL_STATIC_ID => 'GPMS_DEV',
    P_SCHEME => 'OAUTH_CLIENT_CRED', P_BODY => L_ENVELOPE );
    APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE ();
  END PROCESS_EVENTS_OVERRIDE;
  PROCEDURE XX_PROCESS_HOLD (
    P_PROJECT_NUMBER IN VARCHAR2,
    P_CONTRACT_NUMBER IN VARCHAR2 DEFAULT NULL,
    P_EXP_ID IN VARCHAR2 DEFAULT NULL
  ) IS
    L_ROW_COUNT PLS_INTEGER;
    L_VALUES    APEX_JSON.T_VALUES;
    L_EXP_ID    VARCHAR2(4000);
    CURSOR EXPS_CUR (
      CUR_PROJ_NUMBER IN VARCHAR2,
      CUR_EXP_ID IN VARCHAR2
    ) IS
    SELECT
      *
    FROM
      XXGPMS_PROJECT_COSTS
    WHERE
      PROJECT_NUMBER = NVL(CUR_PROJ_NUMBER, PROJECT_NUMBER)
      AND CONTRACT_NUMBER = NVL(P_CONTRACT_NUMBER,CONTRACT_NUMBER)
      AND EXPENDITURE_ITEM_ID IN (
        SELECT
          *
        FROM
          TABLE (APEX_STRING.SPLIT (CUR_EXP_ID,
          ','))
      )
      AND SESSION_ID = V ('APP_SESSION');
    CURSOR EVENTS_CUR (
      CUR_PROJ_NUMBER IN VARCHAR2
    ) IS
    SELECT
      *
    FROM
      XXGPMS_PROJECT_EVENTS
    WHERE
      PROJECT_NUMBER = CUR_PROJ_NUMBER
      AND SESSION_ID = V ('APP_SESSION');
  BEGIN
    WIP_DEBUG ( 3, 2000, 'Process Hold: '
                         || P_PROJECT_NUMBER||
                         ' EXP '||P_EXP_ID, '' );
    PROGRESS_ENTRIES_LOGGER (1, 'Entered');
    DBMS_SESSION.SLEEP (5);
    PROGRESS_ENTRIES_LOGGER (5, 'Performing Process Bill Override.');
 -- SEND THE EXP ID TO THE CURSOR
    IF (P_EXP_ID IS NOT NULL) THEN
      APEX_JSON.PARSE (
        P_VALUES => L_VALUES,
        P_SOURCE => P_EXP_ID
      );
      L_ROW_COUNT := APEX_JSON.GET_COUNT (
        P_PATH => 'expids',
        P_VALUES => L_VALUES
      );
      L_EXP_ID := NULL;
      FOR I IN 1..L_ROW_COUNT LOOP
        L_EXP_ID := L_EXP_ID
                    || ','
                    || APEX_JSON.GET_VARCHAR2 (
          P_PATH => 'expids[%d].EXP_ID',
          P0 => I,
          P_VALUES => L_VALUES
        );
      END LOOP;
      L_EXP_ID := LTRIM(L_EXP_ID, ',');
    END IF;
    WIP_DEBUG (3, 2001, 'EXPID: '
                        || L_EXP_ID, '');
    FOR REC IN EXPS_CUR (P_PROJECT_NUMBER, L_EXP_ID) LOOP
      XX_GPMS.PROCESS_BILL_OVERRIDE (REC.EXPENDITURE_ITEM_ID,P_PROJECT_NUMBER);
    END LOOP;
    PROGRESS_ENTRIES_LOGGER (50, 'Process Bill Override Complete.');
    DBMS_SESSION.SLEEP (5);
    PROGRESS_ENTRIES_LOGGER (52, 'Performing Process Events Override.');
    FOR REC IN EVENTS_CUR (P_PROJECT_NUMBER) LOOP
 --   XX_GPMS.PROCESS_EVENTS_OVERRIDE (REC.EVENT_ID);
      NULL;
    END LOOP;
    PROGRESS_ENTRIES_LOGGER (90, 'Process Events Override Complete.');
    PROGRESS_ENTRIES_LOGGER (100, 'Process Complete.');
  END XX_PROCESS_HOLD;
  PROCEDURE GENERATE_AR_CREDIT (
    P_PROJECT_NUMBER IN VARCHAR2
  ) IS
  BEGIN
    NULL;
  END GENERATE_AR_CREDIT;
  FUNCTION SUBMIT_PARALLEL_ESS_JOB (P_BUSINESS_UNIT VARCHAR2,
                                    P_BUSINESS_UNIT_ID NUMBER,
                                    P_TRANSACTION_SOURCE_ID NUMBER,
                                    P_DOCUMENT_ID NUMBER,
                                    P_EXPENDITURE_BATCH NUMBER)
  RETURN NUMBER
  IS
    L_URL                     VARCHAR2(4000);
    L_ENVELOPE                VARCHAR2(32000);
    L_RESPONSE_CLOB           CLOB;
    L_SVERSION                VARCHAR2(100) := '1.1';
    L_SENVELOPE               CLOB;
    L_SRESPONSE_XML           XMLTYPE;
  BEGIN
    WIP_DEBUG (2, 4340, 'INSIDE', '');
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Authorization';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'Bearer '|| V ('G_SAAS_ACCESS_TOKEN');
    L_URL := INSTANCE_URL
             || ':443/fscmService/ErpIntegrationService';
    WIP_DEBUG (2, 4345, L_URL, '');
    L_SENVELOPE := q'#<?xml version="1.0" encoding="UTF-8"?>#';
    L_SENVELOPE := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/">
                        <soapenv:Header/>
                            <soapenv:Body>
                                <typ:submitESSJobRequest>
                                    <typ:jobPackageName>/oracle/apps/ess/projects/costing/transactions/onestop</typ:jobPackageName>
                                    <typ:jobDefinitionName>ImportProcessParallelEssJob</typ:jobDefinitionName>
                                    <typ:paramList>'
                   || P_BUSINESS_UNIT
                   || '</typ:paramList>
                                    <typ:paramList>'
                   || P_BUSINESS_UNIT_ID
                   || '</typ:paramList>
                                    <typ:paramList>IMPORT_AND_PROCESS</typ:paramList>
                                    <typ:paramList>PREV_NOT_IMPORTED</typ:paramList>
                                    <typ:paramList>#NULL</typ:paramList>
                                    <typ:paramList>'
                   || P_TRANSACTION_SOURCE_ID
                   || '</typ:paramList>
                                    <typ:paramList>'
                   ||P_DOCUMENT_ID||'</typ:paramList>
                                    <typ:paramList>'
                   || P_EXPENDITURE_BATCH
                   || '</typ:paramList>
                                    <typ:paramList>#NULL</typ:paramList>
                                    <typ:paramList>#NULL</typ:paramList>
                                    <typ:paramList>#NULL</typ:paramList>
                                    <typ:paramList>#NULL</typ:paramList>
                                    <typ:paramList>ORA_PJC_SUMMARY</typ:paramList>
                                </typ:submitESSJobRequest>
                            </soapenv:Body>
                        </soapenv:Envelope>';
    WIP_DEBUG (2, 4350, L_SVERSION, '');
    WIP_DEBUG (2, 4400, L_SENVELOPE, '');
 --l_sresponse_xml := apex_web_service.make_request ( p_url => l_url, p_version => l_sversion, p_action => 'submitESSJobRequest', p_envelope => l_senvelope, p_username => g_username, p_password => g_password );
    L_SRESPONSE_XML := APEX_WEB_SERVICE.MAKE_REQUEST ( P_URL => L_URL
    , P_VERSION => L_SVERSION, P_ACTION => 'submitESSJobRequest'
    , P_ENVELOPE => L_SENVELOPE
 -- ,P_CREDENTIAL_STATIC_ID => 'GPMS_DEV'
    -- ,P_SCHEME => 'OAUTH_CLIENT_CRED'
    );
    WIP_DEBUG (2, 4450, '', L_SRESPONSE_XML.GETCLOBVAL());
    WIP_DEBUG (2, 4460, APEX_WEB_SERVICE.G_STATUS_CODE,'' );
    return APEX_WEB_SERVICE.G_STATUS_CODE;
  END;
  FUNCTION POST_JUSTIFICATION (P_JUSTIFICATION VARCHAR2,
                               P_RESPONSE_CODE OUT NUMBER)
  RETURN NUMBER
  IS
  BEGIN
    NULL;
  END;
  FUNCTION PROCESS_TRANSFER_SPLIT (
    P_EXPENDITURE_ITEM_LIST IN VARCHAR2,
    PROJECT_NUMBER IN VARCHAR2,
    P_JUSTIFICATION IN VARCHAR2 DEFAULT NULL,
    P_TOTAL_HOURS IN NUMBER DEFAULT 0
  ) RETURN VARCHAR2 IS
    INPUT_STR                 VARCHAR2(32000);
    VAR1                      NUMBER;
    TEMP_STR                  VARCHAR2(32000);
    EXP_ID                    VARCHAR2(100);
    V_PROJECT_SPLIT_NUM         NUMBER := 0;
    L_URL                     VARCHAR2(4000);
    L_ENVELOPE                VARCHAR2(32000);
    L_RESPONSE_CLOB           CLOB;
    L_SVERSION                VARCHAR2(100) := '1.1';
    L_SENVELOPE               CLOB;
    L_SRESPONSE_XML           XMLTYPE;
    L_QUANTITY                NUMBER;
    L_PROJECT_NUMBER          VARCHAR2(100);
    L_TASK_NUMBER             VARCHAR2(100);
    V_BUSINESS_UNIT           VARCHAR2(100);
    V_BUSINESS_UNIT_ID        NUMBER;
    V_USER_TRANSACTION_SOURCE VARCHAR2(100);
    V_TRANSACTION_SOURCE_ID   NUMBER;
    V_EXPENDITURE_BATCH       VARCHAR2(100);
    V_SESSION_ID              NUMBER;
    V_TRANSACTION_SOURCE      VARCHAR2(100);
    V_DOCUMENT                VARCHAR2(100) ;
    V_DOCUMENT_ENTRY          VARCHAR2(100) ;
    V_STATUS                  VARCHAR2(100);
    V_QUANTITY                NUMBER;
    V_ORIGINAL_QUANTITY       NUMBER;
    V_UNIT_OF_MEASURE         VARCHAR2(100);
    V_PERSON_NAME             VARCHAR2(100);
    V_PROJECT_NUMBER          VARCHAR2(100);
    V_TASK_NUMBER             VARCHAR2(100);
    V_EXPENDITURE_TYPE_NAME   VARCHAR2(100);
    V_DOCUMENT_NAME           VARCHAR2(100);
    V_DOC_ENTRY_NAME          VARCHAR2(100);
    V_UNMATCHED_FLAG          VARCHAR2(1) := 'Y';
    V_ORIG_TRANSACTION_REFERENCE VARCHAR2(100);
    V_EXP_ITEM_DATE DATE;
    V_DOCUMENT_ID NUMBER;
    V_EXP_ORG_ID NUMBER;
    V_EXPENDITURE_COMMENT VARCHAR2(1000);
    V_STATUSCODE NUMBER;
    V_EXP_ID NUMBER;
    L_PERCENTAGE NUMBER;
    V_RESPONSE CLOB;
    V_RESPONSE_CODE NUMBER;
    CURSOR C_PROJECT_SPLIT_CUR IS
    SELECT
      PROJECT_NUMBER,
      TASK_NUMBER,
      QUANTITY,
      PERCENTAGE
    FROM
      XXGPMS_PROJECT_SPLIT
    WHERE
      SESSION_ID = V ('APP_SESSION')
    AND
      ACTION = 'MULTI_SPLIT_TRANS';
  BEGIN
    WIP_DEBUG ( 3, 4000, 'Process Transfer Split: '
                         ||PROJECT_NUMBER, '' );
    SELECT
      BU_NAME,
      BUSINESS_UNIT_ID
      INTO V_BUSINESS_UNIT,
           V_BUSINESS_UNIT_ID
    FROM
      XXGPMS_PROJECT_CONTRACT
    WHERE
      ROWNUM = 1
      AND SESSION_ID = V ('APP_SESSION')
      AND PROJECT_NUMBER = PROJECT_NUMBER;
      WIP_DEBUG ( 2, 4100, V_BUSINESS_UNIT,'');
    FOR I IN (SELECT COLUMN_VALUE EXP_ID FROM TABLE(SELECT APEX_STRING.SPLIT(
              ltrim(P_EXPENDITURE_ITEM_LIST,'-'),'-') FROM DUAL)
             )
    LOOP
        WIP_DEBUG ( 2, 4105, 'Expenditure Item ID '
                         || I.EXP_ID, '' );
      SELECT
        V ('APP_SESSION'),
        TRANSACTION_SOURCE,
        DOCUMENT_NAME,
        DOC_ENTRY_NAME,
        'Pending',
        - 1 * QUANTITY,
        QUANTITY,
        UNIT_OF_MEASURE,
        PERSON_NAME,
        TASK_NUMBER,
        PROJECT_NUMBER,
        EXPENDITURE_TYPE_NAME,
        ORIG_TRANSACTION_REFERENCE,
        EXPENDITURE_ITEM_DATE,
        TRANSACTION_SOURCE_ID,
        DOCUMENT_ID,
        EXP_ORG_ID,
        EXPENDITURE_COMMENT
        INTO V_EXPENDITURE_BATCH,
             V_TRANSACTION_SOURCE,
             V_DOCUMENT,
             V_DOCUMENT_ENTRY,
             V_STATUS,
             V_QUANTITY,
             V_ORIGINAL_QUANTITY,
             V_UNIT_OF_MEASURE,
             V_PERSON_NAME,
             V_TASK_NUMBER,
             V_PROJECT_NUMBER,
             V_EXPENDITURE_TYPE_NAME,
             V_ORIG_TRANSACTION_REFERENCE,
             V_EXP_ITEM_DATE,
             V_TRANSACTION_SOURCE_ID,
             V_DOCUMENT_ID,
             V_EXP_ORG_ID,
             V_EXPENDITURE_COMMENT
      FROM
        XXGPMS_PROJECT_COSTS
      WHERE
        SESSION_ID = V ('APP_SESSION')
        AND EXPENDITURE_ITEM_ID = i.EXP_ID;
      L_URL := INSTANCE_URL
               || '/fscmRestApi/resources/11.13.18.05/unprocessedProjectCosts';
      L_ENVELOPE := '{"ExpenditureBatch" : "'
                    || V_EXPENDITURE_BATCH
                    || '",
                              "TransactionSource" : "'
                    || V_TRANSACTION_SOURCE
                    || '",
                              "BusinessUnit" : "'
                    || V_BUSINESS_UNIT
                    || '",
                              "Document" : "'
                    || V_DOCUMENT
                    || '",
                              "DocumentEntry" : "'
                    || V_DOCUMENT_ENTRY
                    || '",
                              "Status" : "'
                    || V_STATUS
                    || '",
                              "Quantity" : "'
                    || V_QUANTITY
                    || '",
                              "UnitOfMeasureCode" : "'
                    || V_UNIT_OF_MEASURE
                    || '",
                              "PersonName" : "'
                    || V_PERSON_NAME
                    || '",
                              "ReversedOriginalTransactionReference" : "'
                    || V_ORIG_TRANSACTION_REFERENCE
                    || '",
                              "OriginalTransactionReference" : "'
                    || regexp_replace(V_ORIG_TRANSACTION_REFERENCE,'*-[0-9]*','-'||XXGPMS_TRANS_SEQ.NEXTVAL)
                    || '",
                         "UnmatchedNegativeTransactionFlag" : "false",
                          "Comment" : "'
                    || V_EXPENDITURE_COMMENT
                    || '",
                              "ProjectStandardCostCollectionFlexfields" : ['
                    || '{
                                                                                  "_EXPENDITURE_ITEM_DATE" : "'
                    || TO_CHAR(V_EXP_ITEM_DATE, 'YYYY-MM-DD')
                       || '",
                               "_ORGANIZATION_ID" : "'
                        || V_EXP_ORG_ID
                         || '",
                                                                                  "_PROJECT_ID_Display" : "'
                       || V_PROJECT_NUMBER
                       || '",
                                                                                  "_TASK_ID_Display" : "'
                       || V_TASK_NUMBER
                       || '",
                                                                                  "_EXPENDITURE_TYPE_ID_Display" : "'
                       || V_EXPENDITURE_TYPE_NAME
                       || '"}] }';
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/json';
      WIP_DEBUG (2, 4150, L_URL, '');
      WIP_DEBUG (2, 4200, L_ENVELOPE, '');
      L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST (
        P_URL => L_URL,
        P_HTTP_METHOD => 'POST',
        P_SCHEME => 'OAUTH_CLIENT_CRED',
        P_BODY => L_ENVELOPE
      );
      WIP_DEBUG (2, 4250, '', L_RESPONSE_CLOB);
      WIP_DEBUG (3, 4260, APEX_WEB_SERVICE.G_STATUS_CODE, '');
    -- PERFORM_UNPROCESSED_COSTS_CALL(P_EXPENDITURE_ITEM_ID => I.EXP_ID
    --                                , P_REVERSAL => 'Y'
    --                                ,P_INTERNAL_COMMENT=>P_JUSTIFICATION
    --                                ,P_RESPONSE => V_RESPONSE
    --                                ,P_RESPONSE_CODE => V_RESPONSE_CODE);
    IF (APEX_WEB_SERVICE.G_STATUS_CODE IN (200,201)) -- Negative Transaction Post is success
    THEN
    -- 2. Update the Justification on the expenditure item
      V_STATUSCODE := UPDATE_PROJECT_LINES_DFF (I.EXP_ID,P_JUSTIFICATION);
   IF V_STATUSCODE IN (200,201)
      THEN
      -- 3. Post the Split Add Transactions
    -- OPEN C_PROJECT_SPLIT_CUR;
    -- LOOP
    --   FETCH C_PROJECT_SPLIT_CUR INTO L_PROJECT_NUMBER, L_TASK_NUMBER, L_QUANTITY,L_PERCENTAGE;
    --   IF NVL(L_QUANTITY,0) = 0
    --   THEN
    --     L_QUANTITY := V_ORIGINAL_QUANTITY *(L_PERCENTAGE/100);
    --   END IF;
    --   EXIT WHEN C_PROJECT_SPLIT_CUR % NOTFOUND;
    FOR J IN (SELECT *
              FROM   XXGPMS_PROJECT_SPLIT
              WHERE  SESSION_ID = V ('APP_SESSION')
              AND   ACTION = 'MULTI_SPLIT_TRANS'
              )
    LOOP
      L_PROJECT_NUMBER := J.PROJECT_NUMBER;
      L_TASK_NUMBER := J.TASK_NUMBER;
      L_QUANTITY := CASE WHEN J.QUANTITY IS NULL THEN V_ORIGINAL_QUANTITY * (J.PERCENTAGE/100) ELSE J.QUANTITY END;
      L_PERCENTAGE := J.PERCENTAGE;
      V_PROJECT_SPLIT_NUM := V_PROJECT_SPLIT_NUM + 1;
      L_ENVELOPE := '{"ExpenditureBatch" : "'
                    || V_EXPENDITURE_BATCH
                    || '",
                              "TransactionSource" : "'
                    || V_TRANSACTION_SOURCE
                    || '",
                              "BusinessUnit" : "'
                    || V_BUSINESS_UNIT
                    || '",
                              "Document" : "'
                    || V_DOCUMENT
                    || '",
                              "DocumentEntry" : "'
                    || V_DOCUMENT_ENTRY
                    || '",
                              "Status" : "'
                    || V_STATUS
                    || '",
                              "Quantity" : "'
                    || L_QUANTITY
                    || '",
                              "UnitOfMeasureCode" : "'
                    || V_UNIT_OF_MEASURE
                    || '",
                              "PersonName" : "'
                    || V_PERSON_NAME
                    || '",
                              "OriginalTransactionReference" : "'
                    || 'WIP-'||XXGPMS_TRANS_SEQ.NEXTVAL
                    || '",
                              "Comment" : "'
                    || V_EXPENDITURE_COMMENT
                    || '",
                              "ProjectStandardCostCollectionFlexfields" : ['
                    || '{
                                                                                  "_EXPENDITURE_ITEM_DATE" : "'
                    || TO_CHAR(V_EXP_ITEM_DATE, 'YYYY-MM-DD')
                       || '",
                               "_ORGANIZATION_ID" : "'
                        || V_EXP_ORG_ID
                         || '",
                                                                                  "_PROJECT_ID_Display" : "'
                       || L_PROJECT_NUMBER
                       || '",
                                                                                  "_TASK_ID_Display" : "'
                       || L_TASK_NUMBER
                       || '",
                                                                                  "_EXPENDITURE_TYPE_ID_Display" : "'
                       || V_EXPENDITURE_TYPE_NAME
                       || '"}] }';
      WIP_DEBUG (2, 4300, '', L_URL);
      WIP_DEBUG (2, 4305, '', L_ENVELOPE);
      L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST (
        P_URL => L_URL,
        P_HTTP_METHOD => 'POST',
        P_SCHEME => 'OAUTH_CLIENT_CRED',
        P_BODY => L_ENVELOPE
      );
      WIP_DEBUG (2, 4306, '', L_RESPONSE_CLOB);
      WIP_DEBUG (3, 4310, APEX_WEB_SERVICE.G_STATUS_CODE, '');
    IF APEX_WEB_SERVICE.G_STATUS_CODE NOT IN (200,201)
    THEN
      RETURN '</br> Posting for Project: '||L_PROJECT_NUMBER||' Task Number '||L_TASK_NUMBER||' and Quantity '||L_QUANTITY||' failed: '||
               L_RESPONSE_CLOB;
      EXIT;
    END IF;
    END LOOP; -- End of Split and Transfers Loop
    IF APEX_WEB_SERVICE.G_STATUS_CODE IN (200,201)
    THEN
    WIP_DEBUG (3, 4315, 'Started', ''); 
      V_STATUSCODE := SUBMIT_PARALLEL_ESS_JOB(V_BUSINESS_UNIT,
                                    V_BUSINESS_UNIT_ID ,
                                    V_TRANSACTION_SOURCE_ID,
                                    V_DOCUMENT_ID,
                                    V_EXPENDITURE_BATCH);
      WIP_DEBUG (3, 4320, V_STATUSCODE, '');                                    
    END IF;
  ELSE
    RETURN '</br> Justification Update of Reversal Expenditure Item ID: '||I.EXP_ID||' failed: '||
                               L_RESPONSE_CLOB;
  END IF;
  ELSE
    RETURN '</br> Reversal of Expenditure Item ID: '||I.EXP_ID||' failed: '||
                               L_RESPONSE_CLOB;
  END IF;
  END LOOP; -- Expenditures Loop
    -- DELETE FROM XXGPMS_PROJECT_SPLIT
    -- WHERE
    --   SESSION_ID = V ('APP_SESSION');
  END PROCESS_TRANSFER_SPLIT;
  FUNCTION PROCESS_TRANSFER_OR_SPLIT (
    P_EXPENDITURE_ITEM_LIST IN VARCHAR2,
    PROJECT_NUMBER IN VARCHAR2,
    P_JUSTIFICATION IN VARCHAR2 DEFAULT NULL,
    P_DESTINATION_PROJECT IN VARCHAR2 DEFAULT NULL,
    P_DESTINATION_TASKNUMBER IN VARCHAR2 DEFAULT NULL,
    P_DESTINATION_QUANTITY IN NUMBER DEFAULT NULL,
    P_TOTAL_HOURS IN NUMBER DEFAULT 0
  ) RETURN VARCHAR2 IS
    INPUT_STR                 VARCHAR2(32000);
    VAR1                      NUMBER;
    TEMP_STR                  VARCHAR2(32000);
    EXP_ID                    VARCHAR2(100);
    V_PROJECT_SPLIT_NUM         NUMBER := 0;
    L_URL                     VARCHAR2(4000);
    L_ENVELOPE                VARCHAR2(32000);
    L_RESPONSE_CLOB           CLOB;
    L_SVERSION                VARCHAR2(100) := '1.1';
    L_SENVELOPE               CLOB;
    L_SRESPONSE_XML           XMLTYPE;
    L_QUANTITY                NUMBER;
    L_PROJECT_NUMBER          VARCHAR2(100);
    L_TASK_NUMBER             VARCHAR2(100);
    P_BUSINESS_UNIT           VARCHAR2(100);
    P_BUSINESS_UNIT_ID        NUMBER;
    P_USER_TRANSACTION_SOURCE VARCHAR2(100);
    P_TRANSACTION_SOURCE_ID   NUMBER;
    P_EXPENDITURE_BATCH       VARCHAR2(100);
    P_SESSION_ID              NUMBER;
    P_TRANSACTION_SOURCE      VARCHAR2(100);
    P_DOCUMENT                VARCHAR2(100) ;
    P_DOCUMENT_ENTRY          VARCHAR2(100) ;
    P_STATUS                  VARCHAR2(100);
    P_QUANTITY                NUMBER;
    P_UNIT_OF_MEASURE         VARCHAR2(100);
    P_PERSON_NAME             VARCHAR2(100);
    P_PROJECT_NUMBER          VARCHAR2(100);
    P_TASK_NUMBER             VARCHAR2(100);
    P_EXPENDITURE_TYPE_NAME   VARCHAR2(100);
    P_DOCUMENT_NAME           VARCHAR2(100);
    P_DOC_ENTRY_NAME          VARCHAR2(100);
    P_UNMATCHED_FLAG          VARCHAR2(1) := 'Y';
    P_ORIG_TRANSACTION_REFERENCE VARCHAR2(100);
    P_EXP_ITEM_DATE DATE;
    P_DOCUMENT_ID NUMBER;
    P_EXP_ORG_ID NUMBER;
    P_EXPENDITURE_COMMENT VARCHAR2(1000);
    V_STATUSCODE NUMBER;
    V_EXP_ID NUMBER;
    CURSOR C_PROJECT_SPLIT_CUR IS
    SELECT
      PROJECT_NUMBER,
      TASK_NUMBER,
      QUANTITY
    FROM
      XXGPMS_PROJECT_SPLIT
    WHERE
      SESSION_ID = V ('APP_SESSION')
    AND
      ACTION = 'MULTI_SPLIT_TRANS';
  BEGIN
    WIP_DEBUG ( 3, 4000, 'Process Transfer Split: '
                         ||PROJECT_NUMBER, '' );
    WIP_DEBUG ( 2, 4050, 'Expenditure Item List '
                         || P_EXPENDITURE_ITEM_LIST, '' );
    SELECT
      BU_NAME,
      BUSINESS_UNIT_ID
    --   USER_TRANSACTION_SOURCE,
    --   TRANSACTION_SOURCE_ID
      INTO P_BUSINESS_UNIT,
      P_BUSINESS_UNIT_ID
    --   P_USER_TRANSACTION_SOURCE,
    --   P_TRANSACTION_SOURCE_ID
    FROM
      XXGPMS_PROJECT_CONTRACT
    WHERE
      ROWNUM = 1
      AND SESSION_ID = V ('APP_SESSION')
      AND PROJECT_NUMBER = PROJECT_NUMBER;
      WIP_DEBUG ( 2, 4100, P_BUSINESS_UNIT
                         || '-'
                         || P_USER_TRANSACTION_SOURCE, '' );
    -- WHILE (VAR1 > 0) LOOP
    -- FOR I IN (SELECT COLUMN_VALUE EXP_ID FROM TABLE(SELECT APEX_STRING.SPLIT(ltrim(P_EXPENDITURE_ITEM_LIST,'-'),'-') FROM DUAL)
            --  )
    -- LOOP
      SELECT
        V ('APP_SESSION'),
        TRANSACTION_SOURCE,
        DOCUMENT_NAME,
        DOC_ENTRY_NAME,
        'Pending',
        - 1 * QUANTITY,
        UNIT_OF_MEASURE,
        PERSON_NAME,
        TASK_NUMBER,
        PROJECT_NUMBER,
        EXPENDITURE_TYPE_NAME,
        ORIG_TRANSACTION_REFERENCE,
        EXPENDITURE_ITEM_DATE,
        TRANSACTION_SOURCE_ID,
        DOCUMENT_ID,
        EXP_ORG_ID,
        EXPENDITURE_COMMENT
        INTO P_EXPENDITURE_BATCH,
        P_TRANSACTION_SOURCE,
        P_DOCUMENT,
        P_DOCUMENT_ENTRY,
        P_STATUS,
        P_QUANTITY,
        P_UNIT_OF_MEASURE,
        P_PERSON_NAME,
        P_TASK_NUMBER,
        P_PROJECT_NUMBER,
        P_EXPENDITURE_TYPE_NAME,
        P_ORIG_TRANSACTION_REFERENCE,
        P_EXP_ITEM_DATE,
        P_TRANSACTION_SOURCE_ID,
        P_DOCUMENT_ID,
        P_EXP_ORG_ID,
        P_EXPENDITURE_COMMENT
      FROM
        XXGPMS_PROJECT_COSTS
      WHERE
        SESSION_ID = V ('APP_SESSION')
        -- AND ROWNUM <2
        AND EXPENDITURE_ITEM_ID = P_EXPENDITURE_ITEM_LIST;
    --   SELECT CASE WHEN P_UNIT_OF_MEASURE IN ('HOURS','Hours') then
    --          'Time Card'
    --          else
    --          'Miscellaneous Expenditure'
    --          end
    --   into   P_DOCUMENT
    --   FROM   DUAL;
    --    SELECT CASE WHEN P_UNIT_OF_MEASURE IN ('HOURS','Hours') then
    --          'Professional Time'
    --          else
    --          'Miscellaneous Expenditure'
    --          end
    --   into   P_DOCUMENT_ENTRY
    --   FROM   DUAL;
      L_URL := INSTANCE_URL
               || '/fscmRestApi/resources/11.13.18.05/unprocessedProjectCosts';
      L_ENVELOPE := '{"ExpenditureBatch" : "'
                    || P_EXPENDITURE_BATCH
                    || '",
                              "TransactionSource" : "'
                    || P_TRANSACTION_SOURCE
                    || '",
                              "BusinessUnit" : "'
                    || P_BUSINESS_UNIT
                    || '",
                              "Document" : "'
                    || P_DOCUMENT
                    || '",
                              "DocumentEntry" : "'
                    || P_DOCUMENT_ENTRY
                    || '",
                              "Status" : "'
                    || P_STATUS
                    || '",
                              "Quantity" : "'
                    || P_QUANTITY
                    || '",
                              "UnitOfMeasureCode" : "'
                    || P_UNIT_OF_MEASURE
                    || '",
                              "PersonName" : "'
                    || P_PERSON_NAME
                    || '",
                              "ReversedOriginalTransactionReference" : "'
                    || P_ORIG_TRANSACTION_REFERENCE
                    || '",
                              "OriginalTransactionReference" : "'
                    || regexp_replace(P_ORIG_TRANSACTION_REFERENCE,'*-[0-9]*','-'||XXGPMS_TRANS_SEQ.NEXTVAL)
                    || '",
                         "UnmatchedNegativeTransactionFlag" : "false",
                          "Comment" : "'
                    || P_EXPENDITURE_COMMENT
                    || '",
                              "ProjectStandardCostCollectionFlexfields" : ['
                    || '{
                                                                                  "_EXPENDITURE_ITEM_DATE" : "'
                    || TO_CHAR(P_EXP_ITEM_DATE, 'YYYY-MM-DD')
                       || '",
                               "_ORGANIZATION_ID" : "'
                        || P_EXP_ORG_ID
                         || '",
                                                                                  "_PROJECT_ID_Display" : "'
                       || P_PROJECT_NUMBER
                       || '",
                                                                                  "_TASK_ID_Display" : "'
                       || P_TASK_NUMBER
                       || '",
                                                                                  "_EXPENDITURE_TYPE_ID_Display" : "'
                       || P_EXPENDITURE_TYPE_NAME
                       || '"}] }';
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/json';
      WIP_DEBUG (2, 4150, L_URL, '');
      WIP_DEBUG (2, 4200, L_ENVELOPE, '');
      L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST (
        P_URL => L_URL,
        P_HTTP_METHOD => 'POST',
        --p_username => g_username,
        --p_password => g_password,
        -- P_CREDENTIAL_STATIC_ID => 'GPMS_DEV',
        P_SCHEME => 'OAUTH_CLIENT_CRED',
        P_BODY => L_ENVELOPE
      );
      WIP_DEBUG (2, 4250, '', L_RESPONSE_CLOB);
      WIP_DEBUG (3, 4260, APEX_WEB_SERVICE.G_STATUS_CODE, '');
    -- END LOOP;
    IF (APEX_WEB_SERVICE.G_STATUS_CODE IN (200,201)) -- Negative Transaction Post is success
    THEN
    -- 2. Update the Justification on the expenditure item
      V_STATUSCODE := UPDATE_PROJECT_LINES_DFF (P_EXPENDITURE_ITEM_LIST,P_JUSTIFICATION);
      IF V_STATUSCODE IN (200,201)
      THEN
      -- 3. Post the Split Add Transactions
    OPEN C_PROJECT_SPLIT_CUR;
    LOOP
      FETCH C_PROJECT_SPLIT_CUR INTO L_PROJECT_NUMBER, L_TASK_NUMBER, L_QUANTITY;
      EXIT WHEN C_PROJECT_SPLIT_CUR % NOTFOUND;
      -- L_PROJECT_NUMBER := P_DESTINATION_PROJECT;
      -- L_TASK_NUMBER  := P_DESTINATION_TASKNUMBER;
      -- L_QUANTITY := P_DESTINATION_QUANTITY;
      V_PROJECT_SPLIT_NUM := V_PROJECT_SPLIT_NUM + 1;
      L_ENVELOPE := '{"ExpenditureBatch" : "'
                    || P_EXPENDITURE_BATCH
                    || '",
                              "TransactionSource" : "'
                    || P_TRANSACTION_SOURCE
                    || '",
                              "BusinessUnit" : "'
                    || P_BUSINESS_UNIT
                    || '",
                              "Document" : "'
                    || P_DOCUMENT
                    || '",
                              "DocumentEntry" : "'
                    || P_DOCUMENT_ENTRY
                    || '",
                              "Status" : "'
                    || P_STATUS
                    || '",
                              "Quantity" : "'
                    || L_QUANTITY
                    || '",
                              "UnitOfMeasureCode" : "'
                    || P_UNIT_OF_MEASURE
                    || '",
                              "PersonName" : "'
                    || P_PERSON_NAME
                    || '",
                              "OriginalTransactionReference" : "'
                    || 'WIP-'||XXGPMS_TRANS_SEQ.NEXTVAL
                    || '",
                              "Comment" : "'
                    || P_EXPENDITURE_COMMENT
                    || '",
                              "ProjectStandardCostCollectionFlexfields" : ['
                    || '{
                                                                                  "_EXPENDITURE_ITEM_DATE" : "'
                    || TO_CHAR(P_EXP_ITEM_DATE, 'YYYY-MM-DD')
                       || '",
                               "_ORGANIZATION_ID" : "'
                        || P_EXP_ORG_ID
                         || '",
                                                                                  "_PROJECT_ID_Display" : "'
                       || L_PROJECT_NUMBER
                       || '",
                                                                                  "_TASK_ID_Display" : "'
                       || L_TASK_NUMBER
                       || '",
                                                                                  "_EXPENDITURE_TYPE_ID_Display" : "'
                       || P_EXPENDITURE_TYPE_NAME
                       || '"}] }';
      L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST (
        P_URL => L_URL,
        P_HTTP_METHOD => 'POST',
        --p_username => g_username,
        --p_password => g_password,
        -- P_CREDENTIAL_STATIC_ID => 'GPMS_DEV',
        P_SCHEME => 'OAUTH_CLIENT_CRED',
        P_BODY => L_ENVELOPE
      );
      WIP_DEBUG (2, 4300, '', L_RESPONSE_CLOB);
      WIP_DEBUG (3, 4310, APEX_WEB_SERVICE.G_STATUS_CODE, '');
    IF APEX_WEB_SERVICE.G_STATUS_CODE NOT IN (200,201)
    THEN
      RETURN '</br> Posting for Project: '||L_PROJECT_NUMBER||' Task Number '||L_TASK_NUMBER||' and Quantity '||L_QUANTITY||' failed: '||
               L_RESPONSE_CLOB;
      EXIT;
    END IF;
    END LOOP;
    IF APEX_WEB_SERVICE.G_STATUS_CODE IN (200,201)
    THEN
      V_STATUSCODE := SUBMIT_PARALLEL_ESS_JOB(P_BUSINESS_UNIT,
                                    P_BUSINESS_UNIT_ID ,
                                    P_TRANSACTION_SOURCE_ID,
                                    P_DOCUMENT_ID,
                                    P_EXPENDITURE_BATCH);
      WIP_DEBUG (3, 4320, V_STATUSCODE, '');                                    
    END IF;
    DELETE FROM XXGPMS_PROJECT_SPLIT
    WHERE
      SESSION_ID = V ('APP_SESSION');
    RETURN 0;
     WIP_DEBUG (3, 4321, 'Completed', '');  
  ELSE
    RETURN '</br> Justification Update of Reversal Expenditure Item ID: '||P_EXPENDITURE_ITEM_LIST||' failed: '||
                               L_RESPONSE_CLOB;
  END IF;
  ELSE
    RETURN '</br> Reversal of Expenditure Item ID: '||P_EXPENDITURE_ITEM_LIST||' failed: '||
                               L_RESPONSE_CLOB;
  END IF;
  END PROCESS_TRANSFER_OR_SPLIT;
---
  PROCEDURE WIP_ADJUST_HOURS(P_EXPENDITURE_ITEM_ID IN VARCHAR2,
                             P_ADJUSTED_HOURS IN NUMBER,
                             P_JUSTIFICATION IN VARCHAR2,
                             P_RESPONSE_CODE OUT NUMBER,
                             P_RESPONSE OUT VARCHAR2)
  IS
    V_RESPONSE CLOB;
    V_RESPONSE_CODE NUMBER;
    V_PROJECT_COSTS_ROW XXGPMS_PROJECT_COSTS%ROWTYPE;
    V_PROJECT_CONTRACTS_ROW XXGPMS_PROJECT_CONTRACT%ROWTYPE;
  BEGIN
    WIP_DEBUG(2,15000,'Entered into WIP_ADJUST_HOURS: '||P_EXPENDITURE_ITEM_ID,'');
    SELECT *
    INTO   V_PROJECT_COSTS_ROW
    FROM   XXGPMS_PROJECT_COSTS
    WHERE  SESSION_ID = V('APP_SESSION')
    AND    EXPENDITURE_ITEM_ID = TRIM(BOTH '-' FROM P_EXPENDITURE_ITEM_ID);
    WIP_DEBUG(2,15001,'STEP 1','');
    -- 1. REVERSAL OF THE CURRENT EXP LINE
    PERFORM_UNPROCESSED_COSTS_CALL(P_EXPENDITURE_ITEM_ID => P_EXPENDITURE_ITEM_ID
                                   ,P_REVERSAL => 'Y'
                                   ,P_INTERNAL_COMMENT=>TRIM( BOTH ':' FROM P_JUSTIFICATION)
                                --    ,P_STANDARD_BILL_RATE_ATTR => V_PROJECT_COSTS_ROW.STANDARD_BILL_RATE_ATTR
                                --    ,P_PROJECT_BILL_RATE_ATTR => V_PROJECT_COSTS_ROW.PROJECT_BILL_RATE_ATTR
                                --    ,P_REALIZED_BILL_RATE_ATTR => V_PROJECT_COSTS_ROW.REALIZED_BILL_RATE_ATTR
                                   ,P_HOURS_ENTERED => P_ADJUSTED_HOURS
                                   ,P_RESPONSE      => V_RESPONSE
                                   ,P_RESPONSE_CODE => V_RESPONSE_CODE);
    IF (V_RESPONSE_CODE IN (200,201)) -- Negative Transaction Post is success
    THEN
       WIP_DEBUG(2,15002,'STEP 2','');
      -- SPLIT TRANSACTION TO CREATE TWO NEW LINES
       PERFORM_UNPROCESSED_COSTS_CALL(P_EXPENDITURE_ITEM_ID => P_EXPENDITURE_ITEM_ID
                                   ,P_INTERNAL_COMMENT=>TRIM( BOTH ':' FROM P_JUSTIFICATION)
                                   ,P_HOURS_ENTERED => P_ADJUSTED_HOURS
                                   ,P_RESPONSE => V_RESPONSE
                                   ,P_RESPONSE_CODE => V_RESPONSE_CODE);
       WIP_DEBUG(2,15003,'STEP 2.1','');
       PERFORM_UNPROCESSED_COSTS_CALL(P_EXPENDITURE_ITEM_ID => P_EXPENDITURE_ITEM_ID
                                    ,P_INTERNAL_COMMENT=>TRIM( BOTH ':' FROM P_JUSTIFICATION)
                                    ,P_HOURS_ENTERED => V_PROJECT_COSTS_ROW.QUANTITY-P_ADJUSTED_HOURS   
                                     ,P_REALIZED_BILL_RATE_ATTR => 0                                
                                    ,P_RESPONSE => V_RESPONSE
                                    ,P_RESPONSE_CODE => V_RESPONSE_CODE);
       WIP_DEBUG(2,15004,'END OF HOURS ADJUSTMENT','');
       -- 3. Import Costs ESS Job
       IF V_RESPONSE_CODE IN (200,201)
       THEN
       SELECT
          *
       INTO V_PROJECT_CONTRACTS_ROW
       FROM
        XXGPMS_PROJECT_CONTRACT
       WHERE ROWNUM = 1
       AND SESSION_ID = V ('APP_SESSION')
       AND PROJECT_NUMBER = V_PROJECT_COSTS_ROW.PROJECT_NUMBER;
        V_RESPONSE_CODE := SUBMIT_PARALLEL_ESS_JOB(V_PROJECT_CONTRACTS_ROW.BU_NAME,
                                    V_PROJECT_CONTRACTS_ROW.BUSINESS_UNIT_ID ,
                                    V_PROJECT_COSTS_ROW.TRANSACTION_SOURCE_ID,
                                    V_PROJECT_COSTS_ROW.DOCUMENT_ID,
                                    V ('APP_SESSION'));
          P_RESPONSE := V_RESPONSE;
          P_RESPONSE_CODE := V_RESPONSE_CODE;
      ELSE
        P_RESPONSE := V_RESPONSE;
        P_RESPONSE_CODE := V_RESPONSE_CODE;
      END IF;
    ELSE
        WIP_DEBUG(2,15005,'Step1 Failure:'||V_RESPONSE||' CODE:'||V_RESPONSE_CODE,'');
        P_RESPONSE := V_RESPONSE;
        P_RESPONSE_CODE := V_RESPONSE_CODE;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
            WIP_DEBUG(2,15099,sqlerrm,'');
  END;
  FUNCTION WIP_TAG_ADJUSTMENT (
    P_EXPENDITURE_ITEM_LIST IN VARCHAR2,
    P_PROJECT_NUMBER IN VARCHAR2,
    P_ADJ_PCT IN NUMBER,
    P_ADJ_AMT IN NUMBER,
    P_SEL_AMT IN NUMBER,
    P_BILLABLE_FLAG IN VARCHAR2 DEFAULT 'Y',
    P_JUSTIFICATION_COMMENT IN VARCHAR2,
    P_BILL_HOLD_FLAG IN VARCHAR2 DEFAULT NULL
  ) RETURN NUMBER IS
    INPUT_STR                VARCHAR2(32000);
    TEMP_STR                 VARCHAR2(32000);
    -- EXP_ID                   VARCHAR2(100);
    VAR1                     NUMBER;
    RETCODE                  NUMBER;
    P_PROJECT_BILL_RATE_ATTR NUMBER;
    P_PROJECT_BILL_RATE_AMT  NUMBER;
    P_PROJECT_EXP_QTY        NUMBER;
    P_AMT_RED                NUMBER;
    P_NEW_AMT                NUMBER;
    P_NEW_RATE               NUMBER;
    P_PROJECT_AMT_PCT        NUMBER;
    P_SPLIT_COUNT            NUMBER;
    P_BU_NAME                VARCHAR2(100);
  BEGIN
    WIP_DEBUG ( 3, 5000, 'WIP Tag Adjustment: '
                         || P_PROJECT_NUMBER
                         ||' BILLABLE FLAG: '
                         ||P_BILLABLE_FLAG, '' );
    WIP_DEBUG ( 3, 5050, 'WIP EXP ITEMS: '
                         || P_EXPENDITURE_ITEM_LIST
                         || '- adj amt: '
                         || P_ADJ_AMT
                         || '- adj pct: '
                         ||P_ADJ_PCT
                         ||'- sel amt: '
                         ||P_SEL_AMT
                         ||'JUSTIFICATION_COMMENT'
                         ||P_JUSTIFICATION_COMMENT
                         ||'P_BILL_HOLD_FLAG'
                         ||P_BILL_HOLD_FLAG, '' );
    DBMS_SESSION.SLEEP (5);
    SELECT
      COUNT(*) INTO P_SPLIT_COUNT
    FROM
      XXGPMS_PROJECT_SPLIT
    WHERE
      SESSION_ID = V ('APP_SESSION');
    WIP_DEBUG (3, 5100, P_SPLIT_COUNT, '');
    -- IF P_SPLIT_COUNT > 0 THEN
    --   RETCODE := PROCESS_TRANSFER_SPLIT (P_EXPENDITURE_ITEM_LIST, P_PROJECT_NUMBER);
    -- END IF;
    -- UPDATE XXGPMS_PROJECT_COSTS
    -- SET
    --   REALIZED_BILL_RATE_ATTR = 0,
    --   REALIZED_BILL_RATE_AMT = 0,
    --   PROJECT_BILL_RATE_AMT = QUANTITY * PROJECT_BILL_RATE_ATTR
    -- WHERE
    --   BILLABLE_FLAG = 'N';
    INPUT_STR := P_EXPENDITURE_ITEM_LIST;
    -- VAR1 := INSTR(INPUT_STR, '-', 1, 2);
    -- WHILE (VAR1 > 0) LOOP
    --   WIP_DEBUG(3,5101,VAR1||' TEMP_STR:'||TEMP_STR||' INPUT_STR: '||INPUT_STR,'');
    --   TEMP_STR := SUBSTR(INPUT_STR, 2, VAR1 - 2);
    --   EXP_ID := TEMP_STR;
    FOR I IN (SELECT COLUMN_VALUE EXP_ID FROM (SELECT COLUMN_VALUE FROM TABLE(SELECT
    APEX_STRING.SPLIT(P_EXPENDITURE_ITEM_LIST,'-')FROM DUAL))
    WHERE COLUMN_VALUE IS NOT NULL AND COLUMN_VALUE <> '-')
    LOOP
      WIP_DEBUG (3, 5104, I.EXP_ID, '');
      WIP_DEBUG (3, 5105, 'SESSION ID: '
                          ||V('APP_SESSION'), '');
      IF (P_ADJ_PCT <> 0) THEN -- This update statement reduces the rate by an adjusted percentage and calculate the extended amount
        WIP_DEBUG (3, 5105.5, P_BILLABLE_FLAG, '');
        UPDATE XXGPMS_PROJECT_COSTS
        SET
          REALIZED_BILL_RATE_ATTR = PROJECT_BILL_RATE_ATTR - (
            PROJECT_BILL_RATE_ATTR * P_ADJ_PCT / 100
          ),
          REALIZED_BILL_RATE_AMT = QUANTITY * (
            PROJECT_BILL_RATE_ATTR - (PROJECT_BILL_RATE_ATTR * P_ADJ_PCT / 100)
          ),
          PROJECT_BILL_RATE_AMT = QUANTITY * PROJECT_BILL_RATE_ATTR,
          BILLABLE_FLAG = nvl(P_BILLABLE_FLAG,BILLABLE_FLAG),
          INTERNAL_COMMENT = LTRIM(
            P_JUSTIFICATION_COMMENT,
            ':'
          ),
          BILL_HOLD_FLAG = CASE WHEN P_BILL_HOLD_FLAG <> 'BO'
          THEN P_BILL_HOLD_FLAG END
        WHERE
          EXPENDITURE_ITEM_ID = I.EXP_ID
          AND SESSION_ID = V('APP_SESSION');
        WIP_DEBUG (3, 5106, 'Rows Effected:' ||SQL%ROWCOUNT, '');
      ELSE
        P_PROJECT_BILL_RATE_ATTR := 0;
        P_PROJECT_BILL_RATE_AMT := 0;
        P_PROJECT_EXP_QTY := 0;
        P_AMT_RED := 0;
        P_NEW_AMT := 0;
        P_NEW_RATE := 0;
        P_PROJECT_AMT_PCT := 0;
        SELECT
          PROJECT_BILL_RATE_ATTR,
          PROJECT_BILL_RATE_AMT,
          QUANTITY INTO P_PROJECT_BILL_RATE_ATTR,
          P_PROJECT_BILL_RATE_AMT,
          P_PROJECT_EXP_QTY
        FROM
          XXGPMS_PROJECT_COSTS
        WHERE
          EXPENDITURE_ITEM_ID = I.EXP_ID
          AND SESSION_ID = V('APP_SESSION') FETCH FIRST ROW ONLY;
        -- IF BILLABLE FLAG IS SET TO N THEN SET STANDARD BILL RATE,AGREEMENT BILL RATE AND REALIZED BILL RATE TO 0
        IF  NVL(P_BILLABLE_FLAG,'~') = 'N'
        THEN
          UPDATE XXGPMS_PROJECT_COSTS
        SET
          REALIZED_BILL_RATE_ATTR = 0,
          STANDARD_BILL_RATE_ATTR = 0,
          PROJECT_BILL_RATE_ATTR = 0,
          BILLABLE_FLAG = 'N',
          INTERNAL_COMMENT = LTRIM(
            P_JUSTIFICATION_COMMENT,
            ':'
          )
          WHERE
          EXPENDITURE_ITEM_ID = I.EXP_ID;
        ELSE
        P_PROJECT_AMT_PCT := P_PROJECT_BILL_RATE_AMT * 100 / P_SEL_AMT;
        P_AMT_RED := (P_SEL_AMT - P_ADJ_AMT) * P_PROJECT_AMT_PCT / 100;
        P_NEW_AMT := P_PROJECT_BILL_RATE_AMT - P_AMT_RED;
        P_NEW_RATE := P_NEW_AMT / P_PROJECT_EXP_QTY;
        WIP_DEBUG (3, 5150, P_SEL_AMT, '');
        WIP_DEBUG (3, 5200, P_AMT_RED, '');
        WIP_DEBUG (3, 5250, P_NEW_AMT, '');
        WIP_DEBUG (3, 5300, P_NEW_RATE, '');
        WIP_DEBUG (3, 5305, P_BILLABLE_FLAG, '');
        UPDATE XXGPMS_PROJECT_COSTS
        SET
          REALIZED_BILL_RATE_ATTR = P_NEW_RATE,
          REALIZED_BILL_RATE_AMT = P_NEW_AMT,
          PROJECT_BILL_RATE_AMT = QUANTITY * PROJECT_BILL_RATE_ATTR,
          BILLABLE_FLAG = NVL(P_BILLABLE_FLAG,BILLABLE_FLAG),
          INTERNAL_COMMENT = LTRIM(
            P_JUSTIFICATION_COMMENT,
            ':'
          ),
          BILL_HOLD_FLAG = CASE WHEN P_BILL_HOLD_FLAG <> 'BO' THEN P_BILL_HOLD_FLAG END
        WHERE
          EXPENDITURE_ITEM_ID = I.EXP_ID;
        WIP_DEBUG (3, 5306, 'Updated for Exp ID: '||i.exp_id, '');   
      END IF;
    --   INPUT_STR := SUBSTR(INPUT_STR, VAR1, 32000);
    --   VAR1 := INSTR(INPUT_STR, '-', 1, 2);
    END IF;
    END LOOP;
    IF P_BILL_HOLD_FLAG = 'BO'
    THEN
      UPDATE XXGPMS_PROJECT_COSTS
      SET    BILL_HOLD_FLAG = 'O'
      WHERE  EXPENDITURE_ITEM_ID  NOT IN (
        SELECT * FROM TABLE(
          SELECT APEX_STRING.SPLIT(P_EXPENDITURE_ITEM_LIST,'-')
          FROM   DUAL
        )
      )
      AND  SESSION_ID = V('APP_SESSION')
      AND  PROJECT_NUMBER = P_PROJECT_NUMBER;
    END IF;
    RETURN 0;
  END WIP_TAG_ADJUSTMENT;
  PROCEDURE GENERATE_EVENTS (
    P_PROJECT_NUMBER IN VARCHAR2,
    P_AGREEMENT_NUMBER IN VARCHAR2,
    P_BILL_THRU_DATE IN DATE
  ) IS
    P_EVENT_ID               NUMBER;
    P_BILL_TRANS_AMT         NUMBER;
    P_CURRENT_BILL_TRANS_AMT NUMBER;
    EVENT_FOUND_FLAG         VARCHAR2(1);
    CONTRACT_FOUND_FLAG      VARCHAR2(1);
    P_CONTRACT_NUMBER        VARCHAR2(100);
    P_BU_NAME                VARCHAR2(50);
    P_CURRENCY_CODE          VARCHAR2(50);
    P_CONTRACT_TYPE_NAME     VARCHAR2(50);
    P_ORGANIZATION_NAME      VARCHAR2(50);
    P_CONTRACT_LINE_NUMBER   VARCHAR2(50);
    P_EVENT_TYPE_NAME        VARCHAR2(50);
    P_EVENT_DESC             VARCHAR2(50);
    P_TASK_NUMBER            VARCHAR2(50);
  BEGIN
    WIP_DEBUG ( 3, 6000, 'Generate Events: Project:'
                         || P_PROJECT_NUMBER
                         ||' Agreement :'
                         ||P_AGREEMENT_NUMBER, '' );
 -- We have to group by "Project, Contract, WIP Category & Task number" while generating the events.
    DELETE FROM XXGPMS_PROJECT_EVENTS
    WHERE
      SESSION_ID = V('APP_SESSION')
      AND EVENT_TYPE_NAME = 'WIP Adjustment';
    FOR I IN(
      SELECT
        SUM(PROJECT_BILL_RATE_AMT) - SUM(REALIZED_BILL_RATE_AMT) BILL_TRANS_AMT,
        PROJECT_NUMBER,
        CONTRACT_NUMBER                                          AGREEMENT_NUMBER,
        WIP_CATEGORY,
        TASK_NUMBER,
        CONTRACT_LINE_NUM,
        EXP_BU_ID,
        EXP_ORG_ID,
        DEPT_NAME
      FROM
        XXGPMS_PROJECT_COSTS
      WHERE
        PROJECT_NUMBER = NVL(P_PROJECT_NUMBER, PROJECT_NUMBER)
        AND CONTRACT_NUMBER = NVL(P_AGREEMENT_NUMBER, CONTRACT_NUMBER)
        AND SESSION_ID = V ('APP_SESSION')
 -- AND REALIZED_BILL_RATE_ATTR <> 0
        AND NVL(PROJECT_BILL_RATE_AMT, 0) - NVL(REALIZED_BILL_RATE_AMT, 0) <> 0
 -- AND EVENT_ATTR <> 'WIP'
      GROUP BY
        PROJECT_NUMBER,
        CONTRACT_NUMBER,
        CONTRACT_LINE_NUM,
        WIP_CATEGORY,
        TASK_NUMBER,
        EXP_BU_ID,
        EXP_ORG_ID,
        DEPT_NAME
    ) LOOP
      WIP_DEBUG (3, 6050, 'BILL_TRANS_AMT '
                          ||I.BILL_TRANS_AMT, '');
      IF I.BILL_TRANS_AMT <>0 THEN
        BEGIN
          SELECT
            CONTRACT_NUMBER,
            BU_NAME,
            CURRENCY_CODE,
            CONTRACT_TYPE_NAME,
            ORGANIZATION_NAME,
            I.TASK_NUMBER,
 -- task number
 -- 1,
 -- Contract Line Number
            'WIP Adjustment',
 -- Event Type
            'Adjustment created via APEX form' -- Event Description
            INTO P_CONTRACT_NUMBER,
            P_BU_NAME,
            P_CURRENCY_CODE,
            P_CONTRACT_TYPE_NAME,
            P_ORGANIZATION_NAME,
            P_TASK_NUMBER,
 -- P_CONTRACT_LINE_NUMBER,
            P_EVENT_TYPE_NAME,
            P_EVENT_DESC
          FROM
            XXGPMS_PROJECT_CONTRACT
          WHERE
            PROJECT_NUMBER = NVL(I.PROJECT_NUMBER, PROJECT_NUMBER)
            AND CONTRACT_NUMBER = NVL(I.AGREEMENT_NUMBER, CONTRACT_NUMBER)
            AND SESSION_ID = V ('APP_SESSION')
            AND ROWNUM = 1;
          CONTRACT_FOUND_FLAG := 'Y';
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            CONTRACT_FOUND_FLAG := 'N';
          WHEN OTHERS THEN
            CONTRACT_FOUND_FLAG := 'X';
        END;
        WIP_DEBUG (3, 6100, P_CURRENT_BILL_TRANS_AMT, '');
 -- WIP_DEBUG (3, 6150, P_BILL_TRANS_AMT, '');
        WIP_DEBUG (3, 6110, I.PROJECT_NUMBER
                            ||' '
                            ||I.AGREEMENT_NUMBER
                            ||' '
                            ||I.WIP_CATEGORY
                            ||' '
                            ||I.TASK_NUMBER, '');
 --     BEGIN
 --       SELECT
 --         EVENT_ID INTO P_EVENT_ID
 --       FROM
 --         XXGPMS_PROJECT_EVENTS A
 --       WHERE
 --         PROJECT_NUMBER = nvl(i.PROJECT_NUMBER,project_number)
 --       and contract_number = nvl(i.agreement_number,contract_number)
 --       and WIP_CATEGORY = i.WIP_CATEGORY
 --       and TASK_NUMBER = i.TASK_NUMBER
 --       AND SESSION_ID = V ('APP_SESSION')
 --       AND NVL(INVOICEDSTATUS,'Uninvoiced') <> 'Fully Invoiced'
 --       AND EVENT_ID IS NOT NULL
 --       AND ROWNUM <2;
 --       EVENT_FOUND_FLAG := 'Y';
 -- EXCEPTION
 --   WHEN NO_DATA_FOUND THEN
 --     EVENT_FOUND_FLAG := 'N';
 --   WHEN OTHERS THEN
 --     EVENT_FOUND_FLAG := 'X';
 -- END;
        WIP_DEBUG (3, 6150, 'CONTRACT_FOUND_FLAG '
                            ||CONTRACT_FOUND_FLAG
                            ||' EVENT_FOUND_FLAG : '
                            ||EVENT_FOUND_FLAG
                            ||' '
                            ||P_EVENT_ID, '');
        IF CONTRACT_FOUND_FLAG = 'Y' THEN
 -- IF EVENT_FOUND_FLAG = 'N' THEN
          INSERT INTO XXGPMS_PROJECT_EVENTS (
            PROJECT_NUMBER,
            BILL_TRNS_AMOUNT,
            BILL_TRNS_CURRENCY_CODE,
            EVNT_COMPLETION_DATE,
            TASK_NUMBER,
            CONTRACT_NUMBER,
            CONTRACT_LINE_NUMBER,
            BUSINESS_UNIT_NAME,
            ORGANIZATION_NAME,
            CONTRACT_TYPE_NAME,
            EVENT_TYPE_NAME,
            EVENT_DESC,
            FUSION_FLAG,
            SESSION_ID,
            WIP_CATEGORY,
            EXP_BU_ID,
            EXP_ORG_ID,
            DEPT_NAME
          ) VALUES (
            I.PROJECT_NUMBER,
            - 1 * I.BILL_TRANS_AMT,
            P_CURRENCY_CODE,
            P_BILL_THRU_DATE,
            I.TASK_NUMBER,
            I.AGREEMENT_NUMBER,
            I.CONTRACT_LINE_NUM,
            P_BU_NAME,
            I.DEPT_NAME,
            P_CONTRACT_TYPE_NAME,
            P_EVENT_TYPE_NAME,
            P_EVENT_DESC,
            'N',
            V ('APP_SESSION'),
            I.WIP_CATEGORY,
            I.EXP_BU_ID,
            I.EXP_ORG_ID,
            I.DEPT_NAME
          );
          UPDATE XXGPMS_PROJECT_COSTS
          SET
            EVENT_ATTR = 'WIP'
          WHERE
            EVENT_ATTR IS NULL
            AND WIP_CATEGORY = I.WIP_CATEGORY
            AND TASK_NUMBER = I.TASK_NUMBER;
 --   ELSIF EVENT_FOUND_FLAG = 'Y' THEN
 --   -- Event is Found. So We will derive the Transaction Amount value existing on it.
 --   BEGIN
 --     SELECT NVL(SUM(- 1 * NVL(BILL_TRNS_AMOUNT,0)),0) CURRENT_BILL_TRANS_AMT
 --     INTO   P_CURRENT_BILL_TRANS_AMT
 --     FROM   XXGPMS_PROJECT_EVENTS A
 --     WHERE  PROJECT_NUMBER = NVL(I.PROJECT_NUMBER,PROJECT_NUMBER)
 --     AND    CONTRACT_NUMBER = NVL(I.AGREEMENT_NUMBER,CONTRACT_NUMBER)
 --     AND    WIP_CATEGORY = I.WIP_CATEGORY
 --     AND    TASK_NUMBER  = I.TASK_NUMBER
 --     AND   SESSION_ID = V ('APP_SESSION')
 --     AND   NVL(INVOICEDSTATUS,'Uninvoiced') = 'Fully Invoiced';
 --   EXCEPTION
 --     WHEN OTHERS THEN
 --       P_CURRENT_BILL_TRANS_AMT := 0;
 --   END;
 --   P_BILL_TRANS_AMT := NVL(I.BILL_TRANS_AMT,0) - P_CURRENT_BILL_TRANS_AMT;
 --     UPDATE XXGPMS_PROJECT_EVENTS
 --     SET
 --       BILL_TRNS_AMOUNT = - 1 * P_BILL_TRANS_AMT
 --     WHERE  PROJECT_NUMBER  = NVL(I.PROJECT_NUMBER,PROJECT_NUMBER)
 --     AND    CONTRACT_NUMBER = NVL(I.AGREEMENT_NUMBER,CONTRACT_NUMBER)
 --     AND    WIP_CATEGORY    = I.WIP_CATEGORY
 --     AND    TASK_NUMBER     = I.TASK_NUMBER
 --     AND    PROJECT_NUMBER  = i.PROJECT_NUMBER
 --     AND    EVENT_ID        = P_EVENT_ID;
 --     UPDATE XXGPMS_PROJECT_COSTS
 --     SET
 --       EVENT_ATTR = 'WIP'
 --     WHERE
 --       EVENT_ATTR IS NULL
 --       AND PROJECT_NUMBER = nvl(i.PROJECT_NUMBER, project_number)
 --       and contract_number = nvl(i.agreement_number,contract_number)
 --       AND  WIP_CATEGORY   = I.WIP_CATEGORY
 --       AND  TASK_NUMBER    = I.TASK_NUMBER
 --       AND SESSION_ID = V (
 --         'APP_SESSION'
 --       );
 --   END IF;
        END IF;
      END IF;
    END LOOP;
  END GENERATE_EVENTS;
  PROCEDURE POST_EVENT_ATTRIBUTES(
    P_BILLING_EVENTS_UNIQ_ID IN NUMBER,
    P_WIP_CATEGORY IN VARCHAR2,
    P_RESPONSE_CODE OUT NUMBER
  ) IS
    L_URL           VARCHAR2(1000);
    L_ENVELOPE      VARCHAR2(500);
    L_RESPONSE_CLOB CLOB;
  BEGIN
    L_URL := INSTANCE_URL
             ||'/fscmRestApi/resources/11.13.18.05/projectBillingEvents/'
             ||P_BILLING_EVENTS_UNIQ_ID
             ||'/child/billingEventDFF/'
             ||P_BILLING_EVENTS_UNIQ_ID;
    WIP_DEBUG (3, 11000, L_URL, '');
    L_ENVELOPE := '{"wipCategory":"'
                  ||P_WIP_CATEGORY
                  ||'"}';
    WIP_DEBUG (3, 11001, L_ENVELOPE, '');
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/json';
    L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST ( P_URL => L_URL, P_HTTP_METHOD => 'POST',
 --p_username => g_username,
 --p_password => g_password,
 --P_CREDENTIAL_STATIC_ID => 'GPMS_DEV',
    P_SCHEME => 'OAUTH_CLIENT_CRED', P_BODY => L_ENVELOPE );
    WIP_DEBUG (3, 11002, L_RESPONSE_CLOB, '');
    WIP_DEBUG (3, 11003, APEX_WEB_SERVICE.G_STATUS_CODE, '');
    P_RESPONSE_CODE := APEX_WEB_SERVICE.G_STATUS_CODE;
    APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE ();
  END;
  PROCEDURE PARSE_JOB_ID (
    P_RESPONSE IN XMLTYPE,
    P_JOB_ID OUT NUMBER
  ) IS
    L_CLOB_REPORT_RESPONSE CLOB;
    L_XML_REPORT_RESPONSE  XMLTYPE;
  BEGIN
    WIP_DEBUG (3, 130000, P_RESPONSE.GETCLOBVAL(), '');
    L_CLOB_REPORT_RESPONSE := P_RESPONSE.GETCLOBVAL();
    L_CLOB_REPORT_RESPONSE := APEX_WEB_SERVICE.PARSE_XML_CLOB ( P_XML => P_RESPONSE, P_XPATH => ' //err/response'
 --, P_NS    => ' xmlns="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types"'
    );
    WIP_DEBUG (3, 130001, 'Step 1 Response ', L_CLOB_REPORT_RESPONSE);
    L_CLOB_REPORT_RESPONSE := REPLACE(L_CLOB_REPORT_RESPONSE, RTRIM(SUBSTR(L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '<!'), INSTR(L_CLOB_REPORT_RESPONSE, '<env:')-1), '<env:Envel'), '');
    WIP_DEBUG (3, 130001, 'Step 2 Response ', L_CLOB_REPORT_RESPONSE);
    L_CLOB_REPORT_RESPONSE := REPLACE(L_CLOB_REPORT_RESPONSE, SUBSTR(L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '------'), INSTR(L_CLOB_REPORT_RESPONSE, ']]>')-1), '')
                              ||'</response>';
    WIP_DEBUG (3, 130001, 'Step 3 Response ', L_CLOB_REPORT_RESPONSE);
    L_XML_REPORT_RESPONSE := SYS.XMLTYPE.CREATEXML(L_CLOB_REPORT_RESPONSE);
    L_CLOB_REPORT_RESPONSE := APEX_WEB_SERVICE.PARSE_XML_CLOB ( P_XML => L_XML_REPORT_RESPONSE, P_XPATH => '//response/submitESSJobRequestResponse'
 --, P_NS    => 'xmlns="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types"'
    );
    WIP_DEBUG (3, 130002, 'Parsed Response ', L_CLOB_REPORT_RESPONSE);
  END;
--
   PROCEDURE GENERATE_EVENTS_AND_POST(
    P_PROJECT_NUMBER IN VARCHAR2 DEFAULT NULL,
    P_BILL_THRU_DATE IN DATE,
    P_CONTRACT_NUMBER IN VARCHAR2,
    P_JUSTIFICATION IN VARCHAR2,
    P_TOTAL_UP_DOWN IN NUMBER DEFAULT 0,
    P_BILL_FROM_DATE IN DATE DEFAULT TO_DATE('01-01-1997', 'MM-DD-YYYY')
  )
  IS
  L_URL                       VARCHAR2(4000);
    NAME                        VARCHAR2(4000);
    BUFFER                      VARCHAR2(4000);
    L_ENVELOPE                  VARCHAR2(32000);
    L_SENVELOPE                 CLOB;
    L_RESPONSE_XML              VARCHAR2(32000);
    L_SRESPONSE_XML             XMLTYPE;
    L_RESPONSE_CLOB             CLOB;
    P_NIC_NUMBER                VARCHAR2(100);
    L_VERSION                   VARCHAR2(100);
    L_SVERSION                  VARCHAR2(100):= '1.1';
    L_TEMP                      VARCHAR2(32000);
    P_BUSINESS_UNIT_NAME        VARCHAR2(100);
    P_ORGANIZATION_NAME         VARCHAR2(100);
    P_CONTRACT_TYPE_NAME        VARCHAR2(100);
    P_CONTRACT_LINE_NUMBER      VARCHAR2(100);
    P_EVENT_TYPE_NAME           VARCHAR2(100);
    P_EVENT_DESCRIPTION         VARCHAR2(100);
    P_TASK_NUMBER               VARCHAR2(100);
    P_COMPLETION_DATE           DATE;
    P_BILL_TRANS_AMOUNT         NUMBER;
    P_PROJECT_BILL_RATE_AMT     NUMBER;
    P_EVENT_ID                  NUMBER;
    P_FUSION_FLAG               VARCHAR2(1) := 'N';
    EVENT_FOUND_FLAG            VARCHAR2(1) := 'N';
    P_EVENT_ID_TMP              VARCHAR2(50);
    P_EVENT_NO_RET_TMP          VARCHAR2(10);
    P_EVENT_NUM                 VARCHAR2(10);
    P_PROJECT_NAME              VARCHAR2(100);
    P_PROJECT_ID                NUMBER;
    P_BU_NAME                   VARCHAR2(100);
    P_BU_ID                     NUMBER;
    P_INVOICE_DATE              DATE;
    P_CONTRACT_ID               NUMBER;
    TEMP_CONTRACT_NUMBER        VARCHAR2(10);
    TEMP_CONTRACT_ID            NUMBER;
    CMTE_APPROVAL_REQUIRED_FLAG VARCHAR2(1);
    CMTE_APPROVAL_ADJUSTMENT    NUMBER;
    P_CMTE_BILL_RATE_AMT        NUMBER;
    P_CMTE_EVNT_RATE_AMT        NUMBER;
    CMTE_ADJ_PCT                NUMBER;
    LV_RESPONSE                 NUMBER := 1;
    V_RESPONSE_CODE             NUMBER;
    LS_RESPONSE_CLOB            CLOB;
    L_JOB_ID                    VARCHAR2(100);
  BEGIN
      FOR I IN (
        SELECT
          BUSINESS_UNIT_NAME,
          ORGANIZATION_NAME,
          CONTRACT_TYPE_NAME,
          CONTRACT_LINE_NUMBER,
          EVENT_TYPE_NAME,
          EVENT_DESC,
          TASK_NUMBER,
          EVNT_COMPLETION_DATE,
          BILL_TRNS_AMOUNT,
          EVENT_ID,
          FUSION_FLAG,
          EVENT_NUM,
          WIP_CATEGORY,
          PROJECT_NUMBER,
          EXP_BU_ID,
          EXP_ORG_ID,
          DEPT_NAME
 --   DECODE(P_PROJECT_NUMBER, NULL, NULL, PROJECT_NUMBER) PROJECT_NUMBER
        FROM
          XXGPMS_PROJECT_EVENTS
        WHERE
          NVL(PROJECT_NUMBER, '~')      = NVL(P_PROJECT_NUMBER, NVL(PROJECT_NUMBER, '~'))
          AND NVL(CONTRACT_NUMBER, '~') = NVL(P_CONTRACT_NUMBER, NVL(CONTRACT_NUMBER, '~'))
          AND SESSION_ID                = V ('APP_SESSION')
          AND NVL(INVOICEDSTATUS, 'Uninvoiced') <> 'Fully Invoiced'
          AND FUSION_FLAG <> 'Y'
      ) LOOP
        EVENT_FOUND_FLAG := 'Y';
        WIP_DEBUG (3, 7199, 'GENERATE EVENTS AND POST -- '||
                            'BEFORE: '
                            ||I.WIP_CATEGORY
                            ||' '
                            ||I.TASK_NUMBER
                            ||' '
                            ||I.BILL_TRNS_AMOUNT, '');
        IF NVL(I.BILL_TRNS_AMOUNT, 0) <> 0 THEN
          IF I.FUSION_FLAG = 'N' THEN
 --- Create Project Events -------
            L_URL := INSTANCE_URL
                     || '/fscmRestApi/resources/11.13.18.05/projectBillingEvents';
            WIP_DEBUG (3, 7201, L_URL, '');
            L_ENVELOPE := '{"BusinessUnitName" : "'
                          || I.BUSINESS_UNIT_NAME
                          || '",
                          "OrganizationName":"'
                          ||I.DEPT_NAME
                          ||'",
                           "ContractTypeName" : "'
                          || I.CONTRACT_TYPE_NAME
                          || '",
                                        "ContractNumber" : "'
                          || P_CONTRACT_NUMBER
                          || '",
                                        "ContractLineNumber" : "'
                          || I.CONTRACT_LINE_NUMBER
                          || '",
                                        "EventTypeName" : "'
                          || I.EVENT_TYPE_NAME
                          || '",
                                        "EventDescription" : "'
                          || I.EVENT_DESC
                          || '",
                                        "ProjectNumber" : "'
                          || I.PROJECT_NUMBER
                          || '",
                                        "TaskNumber" : "'
                          || I.TASK_NUMBER
                          || '",
                                        "CompletionDate" : "'
                          || TO_CHAR(I.EVNT_COMPLETION_DATE, 'YYYY-MM-DD')
                             || '",
                                        "BillTrnsAmount" : '
                             || I.BILL_TRNS_AMOUNT
                             ||'
           }';
            WIP_DEBUG (3, 7202, L_ENVELOPE, '');
            APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
            APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/json';
            L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST (
              P_URL => L_URL,
              P_HTTP_METHOD => 'POST',
 --p_username => g_username,
 --p_password => g_password,
 --P_CREDENTIAL_STATIC_ID => 'GPMS_DEV',
              P_SCHEME => 'OAUTH_CLIENT_CRED',
              P_BODY => L_ENVELOPE
            );
            WIP_DEBUG (3, 7203, L_RESPONSE_CLOB, '');
            WIP_DEBUG (3, 7203.5, APEX_WEB_SERVICE.G_STATUS_CODE, '');
            IF APEX_WEB_SERVICE.G_STATUS_CODE IN (200, 201) THEN
              WIP_DEBUG (3, 7204, 'Response of Posting Event for Agreement '
                                  ||P_CONTRACT_NUMBER
                                  ||' Project '
                                  ||I.PROJECT_NUMBER
                                  ||' WIP Category '
                                  ||I.WIP_CATEGORY
                                  ||' Task Number '
                                  ||I.TASK_NUMBER
                                  ||'Org Name'
                                  || i.dept_name
                                  ||' is '
                                  ||APEX_WEB_SERVICE.G_STATUS_CODE, '');
              LV_RESPONSE := LV_RESPONSE * 1;
 -- NOW THAT THE EVENT IS POSTED, LETS POST THE WIP CATEGORY
              SELECT
                JSON_QUERY ( L_RESPONSE_CLOB, '$.EventId' WITH WRAPPER )     AS VALUE,
                JSON_QUERY ( L_RESPONSE_CLOB, '$.EventNumber' WITH WRAPPER ) AS VALUE INTO P_EVENT_ID_TMP,
                P_EVENT_NO_RET_TMP
              FROM
                DUAL;
              P_EVENT_ID_TMP := REPLACE(REPLACE(P_EVENT_ID_TMP, '[', ''), ']', '');
              WIP_DEBUG (3, 7205, 'After Posting Event Data '
                                  ||P_EVENT_ID_TMP
                                  ||' '
                                  ||P_EVENT_NO_RET_TMP
                                  ||' '
                                  ||LV_RESPONSE
                                  ||' '
                                  ||I.WIP_CATEGORY, '');
 -- POST_EVENT_ATTRIBUTES(P_EVENT_ID_TMP,I.WIP_CATEGORY,V_RESPONSE_CODE);
              L_URL := INSTANCE_URL
                       ||'/fscmRestApi/resources/11.13.18.05/projectBillingEvents/'
                       ||P_EVENT_ID_TMP
                       ||'/child/billingEventDFF/'
                       ||P_EVENT_ID_TMP;
              WIP_DEBUG (3, 11000, L_URL, '');
              L_ENVELOPE := '{"wipCategory":"'
                            ||I.WIP_CATEGORY
                            ||'"
                              ,"revenueOffice":"'
                             ||I.EXP_BU_ID
                             ||'"
                             ,"expenditureOrganization":"'
                             ||I.EXP_ORG_ID
                             ||'"}';
              WIP_DEBUG (3, 11001, L_ENVELOPE, '');
              APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
              APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/json';
              L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST (
                P_URL => L_URL,
                P_HTTP_METHOD => 'PATCH',
 --p_username => g_username,
 --p_password => g_password,
 --P_CREDENTIAL_STATIC_ID => 'GPMS_DEV',
                P_SCHEME => 'OAUTH_CLIENT_CRED',
                P_BODY => L_ENVELOPE
              );
              WIP_DEBUG (3, 11002, L_RESPONSE_CLOB, '');
              V_RESPONSE_CODE := APEX_WEB_SERVICE.G_STATUS_CODE;
              WIP_DEBUG (3, 7206, 'Response of Posting Event WIP Category for Agreement '
                                  ||P_CONTRACT_NUMBER
                                  ||' Project '
                                  ||I.PROJECT_NUMBER
                                  ||' WIP Category '
                                  ||I.WIP_CATEGORY
                                  ||' Task Number '
                                  ||I.TASK_NUMBER
                                  ||' is '
                                  ||V_RESPONSE_CODE, '');
              IF V_RESPONSE_CODE NOT IN (200, 201) THEN
                LV_RESPONSE := 0;
                EXIT;
              END IF;
            ELSE
              LV_RESPONSE := 0;
              EXIT;
            END IF;
            UPDATE XXGPMS_PROJECT_EVENTS
            SET
              FUSION_FLAG = 'Y',
              EVENT_ID = TO_NUMBER(
                SUBSTR(P_EVENT_ID_TMP, 2, LENGTH(P_EVENT_ID_TMP) - 2)
              ),
              EVENT_NUM = TO_NUMBER(
                SUBSTR( P_EVENT_NO_RET_TMP, 2, LENGTH(P_EVENT_NO_RET_TMP) - 2 )
              )
            WHERE
              PROJECT_NUMBER = NVL( P_PROJECT_NUMBER, PROJECT_NUMBER )
              AND CONTRACT_NUMBER = NVL( P_CONTRACT_NUMBER, CONTRACT_NUMBER )
              AND WIP_CATEGORY = I.WIP_CATEGORY
              AND TASK_NUMBER = I.TASK_NUMBER
              AND SESSION_ID = V ( 'APP_SESSION' )
              AND NVL( INVOICEDSTATUS, 'Uninvoiced' ) <> 'Fully Invoiced';
            UPDATE XXGPMS_PROJECT_COSTS
            SET
              EVENT_ATTR = P_CONTRACT_NUMBER
                           || ' - '
                           || TO_NUMBER(
                SUBSTR( P_EVENT_NO_RET_TMP, 2, LENGTH(P_EVENT_NO_RET_TMP) - 2 )
              )
            WHERE
              EVENT_ATTR IS NOT NULL;
          ELSE
            L_URL := INSTANCE_URL
                     || '/fscmRestApi/resources/11.13.18.05/projectBillingEvents/'
                     || I.EVENT_ID;
            WIP_DEBUG (3, 7210, L_URL, '');
            L_ENVELOPE := '{"BillTrnsAmount" : '
                          || I.BILL_TRNS_AMOUNT
                          || '}';
            WIP_DEBUG (3, 7211, L_ENVELOPE, '');
            APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
            APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/json';
            L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST (
              P_URL => L_URL,
              P_HTTP_METHOD => 'PATCH',
 --p_username => g_username,
 --p_password => g_password,
 --   P_CREDENTIAL_STATIC_ID => 'GPMS_DEV',
              P_SCHEME => 'OAUTH_CLIENT_CRED',
              P_BODY => L_ENVELOPE
            );
            WIP_DEBUG (3, 7212, L_RESPONSE_CLOB, '');
            WIP_DEBUG (3, 7213, 'Response of PATCHING Event for Agreement '
                                ||P_CONTRACT_NUMBER
                                ||' Project '
                                ||I.PROJECT_NUMBER
                                ||' WIP Category '
                                ||I.WIP_CATEGORY
                                ||' Task Number '
                                ||I.TASK_NUMBER
                                ||' is '
                                ||APEX_WEB_SERVICE.G_STATUS_CODE, '');
            IF APEX_WEB_SERVICE.G_STATUS_CODE IN (200, 201) THEN
              LV_RESPONSE := LV_RESPONSE * 1;
            ELSE
              LV_RESPONSE := 0;
              EXIT;
            END IF;
            UPDATE XXGPMS_PROJECT_COSTS
            SET
              EVENT_ATTR = P_CONTRACT_NUMBER
                           || ' - '
                           || I.EVENT_NUM
            WHERE
              EVENT_ATTR IS NOT NULL;
          END IF;
        END IF;
      END LOOP;
      WIP_DEBUG (3, 7213, 'Final Response Status after Event Loop Exiting is: '
                          ||LV_RESPONSE, '');
    EXCEPTION
      WHEN OTHERS THEN
        EVENT_FOUND_FLAG := 'N';
        P_BILL_TRANS_AMOUNT := 0;
    END;
  PROCEDURE GENERATE_DRAFT_INVOICE (
    P_PROJECT_NUMBER IN VARCHAR2 DEFAULT NULL,
    P_BILL_THRU_DATE IN DATE,
    P_CONTRACT_NUMBER IN VARCHAR2,
    P_JUSTIFICATION IN VARCHAR2,
    P_TOTAL_UP_DOWN IN NUMBER DEFAULT 0,
    P_BILL_FROM_DATE IN DATE DEFAULT TO_DATE('01-01-1997', 'MM-DD-YYYY')
  ) IS
    L_URL                       VARCHAR2(4000);
    NAME                        VARCHAR2(4000);
    BUFFER                      VARCHAR2(4000);
    L_ENVELOPE                  VARCHAR2(32000);
    L_SENVELOPE                 CLOB;
    L_RESPONSE_XML              VARCHAR2(32000);
    L_SRESPONSE_XML             XMLTYPE;
    L_RESPONSE_CLOB             CLOB;
    P_NIC_NUMBER                VARCHAR2(100);
    L_VERSION                   VARCHAR2(100);
    L_SVERSION                  VARCHAR2(100):= '1.1';
    L_TEMP                      VARCHAR2(32000);
    P_BUSINESS_UNIT_NAME        VARCHAR2(100);
    P_ORGANIZATION_NAME         VARCHAR2(100);
    P_CONTRACT_TYPE_NAME        VARCHAR2(100);
    P_CONTRACT_LINE_NUMBER      VARCHAR2(100);
    P_EVENT_TYPE_NAME           VARCHAR2(100);
    P_EVENT_DESCRIPTION         VARCHAR2(100);
    P_TASK_NUMBER               VARCHAR2(100);
    P_COMPLETION_DATE           DATE;
    P_BILL_TRANS_AMOUNT         NUMBER;
    P_PROJECT_BILL_RATE_AMT     NUMBER;
    P_EVENT_ID                  NUMBER;
    P_FUSION_FLAG               VARCHAR2(1) := 'N';
    EVENT_FOUND_FLAG            VARCHAR2(1) := 'N';
    P_EVENT_ID_TMP              VARCHAR2(50);
    P_EVENT_NO_RET_TMP          VARCHAR2(10);
    P_EVENT_NUM                 VARCHAR2(10);
    P_PROJECT_NAME              VARCHAR2(100);
    P_PROJECT_ID                NUMBER;
    P_BU_NAME                   VARCHAR2(100);
    P_BU_ID                     NUMBER;
    P_INVOICE_DATE              DATE;
    P_CONTRACT_ID               NUMBER;
    TEMP_CONTRACT_NUMBER        VARCHAR2(10);
    TEMP_CONTRACT_ID            NUMBER;
    CMTE_APPROVAL_REQUIRED_FLAG VARCHAR2(1);
    CMTE_APPROVAL_ADJUSTMENT    NUMBER;
    P_CMTE_BILL_RATE_AMT        NUMBER;
    P_CMTE_EVNT_RATE_AMT        NUMBER;
    CMTE_ADJ_PCT                NUMBER;
    LV_RESPONSE                 NUMBER := 1;
    V_RESPONSE_CODE             NUMBER;
    LS_RESPONSE_CLOB            CLOB;
    L_JOB_ID                    VARCHAR2(100);
  BEGIN
    WIP_DEBUG ( 3, 7000, 'Generate Draft Invoice: Project'
                         || P_PROJECT_NUMBER
                         ||' Agreement:'
                         ||P_CONTRACT_NUMBER, '' );
    WIP_DEBUG (3, 7050, P_PROJECT_NUMBER, '');
    WIP_DEBUG ( 3, 7100, TO_CHAR(P_BILL_THRU_DATE, 'MM-DD-YYYY'), '' );
    WIP_DEBUG ( 3, 7101, TO_CHAR(P_BILL_FROM_DATE, 'MM-DD-YYYY'), '' );
    WIP_DEBUG (3, 7150, P_CONTRACT_NUMBER, '');
    L_VERSION := '1.2';
    BEGIN
      FOR I IN (
        SELECT
          BUSINESS_UNIT_NAME,
          ORGANIZATION_NAME,
          CONTRACT_TYPE_NAME,
          CONTRACT_LINE_NUMBER,
          EVENT_TYPE_NAME,
          EVENT_DESC,
          TASK_NUMBER,
          EVNT_COMPLETION_DATE,
          BILL_TRNS_AMOUNT,
          EVENT_ID,
          FUSION_FLAG,
          EVENT_NUM,
          WIP_CATEGORY,
          PROJECT_NUMBER,
          EXP_BU_ID,
          EXP_ORG_ID,
          DEPT_NAME
 --   DECODE(P_PROJECT_NUMBER, NULL, NULL, PROJECT_NUMBER) PROJECT_NUMBER
        FROM
          XXGPMS_PROJECT_EVENTS
        WHERE
          NVL(PROJECT_NUMBER, '~') = NVL(P_PROJECT_NUMBER, NVL(PROJECT_NUMBER, '~'))
          AND NVL(CONTRACT_NUMBER, '~') = NVL(P_CONTRACT_NUMBER, NVL(CONTRACT_NUMBER, '~'))
          AND SESSION_ID = V ('APP_SESSION')
          AND NVL(INVOICEDSTATUS, 'Uninvoiced') <> 'Fully Invoiced'
      ) LOOP
        EVENT_FOUND_FLAG := 'Y';
        WIP_DEBUG (3, 7199, 'BEFORE: '
                            ||I.WIP_CATEGORY
                            ||' '
                            ||I.TASK_NUMBER
                            ||' '
                            ||I.BILL_TRNS_AMOUNT, '');
        IF NVL(I.BILL_TRNS_AMOUNT, 0) <> 0 THEN
          IF I.FUSION_FLAG = 'N' THEN
 --- Create Project Events -------
            L_URL := INSTANCE_URL
                     || '/fscmRestApi/resources/11.13.18.05/projectBillingEvents';
            WIP_DEBUG (3, 7201, L_URL, '');
            L_ENVELOPE := '{"BusinessUnitName" : "'
                          || I.BUSINESS_UNIT_NAME
                          || '",
                          "OrganizationName":"'
                          ||I.DEPT_NAME
                          ||'",
                           "ContractTypeName" : "'
                          || I.CONTRACT_TYPE_NAME
                          || '",
                                        "ContractNumber" : "'
                          || P_CONTRACT_NUMBER
                          || '",
                                        "ContractLineNumber" : "'
                          || I.CONTRACT_LINE_NUMBER
                          || '",
                                        "EventTypeName" : "'
                          || I.EVENT_TYPE_NAME
                          || '",
                                        "EventDescription" : "'
                          || I.EVENT_DESC
                          || '",
                                        "ProjectNumber" : "'
                          || I.PROJECT_NUMBER
                          || '",
                                        "TaskNumber" : "'
                          || I.TASK_NUMBER
                          || '",
                                        "CompletionDate" : "'
                          || TO_CHAR(I.EVNT_COMPLETION_DATE, 'YYYY-MM-DD')
                             || '",
                                        "BillTrnsAmount" : '
                             || I.BILL_TRNS_AMOUNT
                             ||'
           }';
            WIP_DEBUG (3, 7202, L_ENVELOPE, '');
            APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
            APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/json';
            L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST (
              P_URL => L_URL,
              P_HTTP_METHOD => 'POST',
 --p_username => g_username,
 --p_password => g_password,
 --P_CREDENTIAL_STATIC_ID => 'GPMS_DEV',
              P_SCHEME => 'OAUTH_CLIENT_CRED',
              P_BODY => L_ENVELOPE
            );
            WIP_DEBUG (3, 7203, L_RESPONSE_CLOB, '');
            WIP_DEBUG (3, 7203.5, APEX_WEB_SERVICE.G_STATUS_CODE, '');
            IF APEX_WEB_SERVICE.G_STATUS_CODE IN (200, 201) THEN
              WIP_DEBUG (3, 7204, 'Response of Posting Event for Agreement '
                                  ||P_CONTRACT_NUMBER
                                  ||' Project '
                                  ||I.PROJECT_NUMBER
                                  ||' WIP Category '
                                  ||I.WIP_CATEGORY
                                  ||' Task Number '
                                  ||I.TASK_NUMBER
                                  ||'Org Name'
                                  || i.dept_name
                                  ||' is '
                                  ||APEX_WEB_SERVICE.G_STATUS_CODE, '');
              LV_RESPONSE := LV_RESPONSE * 1;
 -- NOW THAT THE EVENT IS POSTED, LETS POST THE WIP CATEGORY
              SELECT
                JSON_QUERY ( L_RESPONSE_CLOB, '$.EventId' WITH WRAPPER )     AS VALUE,
                JSON_QUERY ( L_RESPONSE_CLOB, '$.EventNumber' WITH WRAPPER ) AS VALUE INTO P_EVENT_ID_TMP,
                P_EVENT_NO_RET_TMP
              FROM
                DUAL;
              P_EVENT_ID_TMP := REPLACE(REPLACE(P_EVENT_ID_TMP, '[', ''), ']', '');
              WIP_DEBUG (3, 7205, 'After Posting Event Data '
                                  ||P_EVENT_ID_TMP
                                  ||' '
                                  ||P_EVENT_NO_RET_TMP
                                  ||' '
                                  ||LV_RESPONSE
                                  ||' '
                                  ||I.WIP_CATEGORY, '');
 -- POST_EVENT_ATTRIBUTES(P_EVENT_ID_TMP,I.WIP_CATEGORY,V_RESPONSE_CODE);
              L_URL := INSTANCE_URL
                       ||'/fscmRestApi/resources/11.13.18.05/projectBillingEvents/'
                       ||P_EVENT_ID_TMP
                       ||'/child/billingEventDFF/'
                       ||P_EVENT_ID_TMP;
              WIP_DEBUG (3, 11000, L_URL, '');
              L_ENVELOPE := '{"wipCategory":"'
                            ||I.WIP_CATEGORY
                            ||'"
                              ,"revenueOffice":"'
                             ||I.EXP_BU_ID
                             ||'"
                             ,"expenditureOrganization":"'
                             ||I.EXP_ORG_ID
                             ||'"}';
              WIP_DEBUG (3, 11001, L_ENVELOPE, '');
              APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
              APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/json';
              L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST (
                P_URL => L_URL,
                P_HTTP_METHOD => 'PATCH',
 --p_username => g_username,
 --p_password => g_password,
 --P_CREDENTIAL_STATIC_ID => 'GPMS_DEV',
                P_SCHEME => 'OAUTH_CLIENT_CRED',
                P_BODY => L_ENVELOPE
              );
              WIP_DEBUG (3, 11002, L_RESPONSE_CLOB, '');
              V_RESPONSE_CODE := APEX_WEB_SERVICE.G_STATUS_CODE;
              WIP_DEBUG (3, 7206, 'Response of Posting Event WIP Category for Agreement '
                                  ||P_CONTRACT_NUMBER
                                  ||' Project '
                                  ||I.PROJECT_NUMBER
                                  ||' WIP Category '
                                  ||I.WIP_CATEGORY
                                  ||' Task Number '
                                  ||I.TASK_NUMBER
                                  ||' is '
                                  ||V_RESPONSE_CODE, '');
              IF V_RESPONSE_CODE NOT IN (200, 201) THEN
                LV_RESPONSE := 0;
                EXIT;
              END IF;
            ELSE
              LV_RESPONSE := 0;
              EXIT;
            END IF;
            UPDATE XXGPMS_PROJECT_EVENTS
            SET
              FUSION_FLAG = 'Y',
              EVENT_ID = TO_NUMBER(
                SUBSTR(P_EVENT_ID_TMP, 2, LENGTH(P_EVENT_ID_TMP) - 2)
              ),
              EVENT_NUM = TO_NUMBER(
                SUBSTR( P_EVENT_NO_RET_TMP, 2, LENGTH(P_EVENT_NO_RET_TMP) - 2 )
              )
            WHERE
              PROJECT_NUMBER = NVL( P_PROJECT_NUMBER, PROJECT_NUMBER )
              AND CONTRACT_NUMBER = NVL( P_CONTRACT_NUMBER, CONTRACT_NUMBER )
              AND WIP_CATEGORY = I.WIP_CATEGORY
              AND TASK_NUMBER = I.TASK_NUMBER
              AND SESSION_ID = V ( 'APP_SESSION' )
              AND NVL( INVOICEDSTATUS, 'Uninvoiced' ) <> 'Fully Invoiced';
            UPDATE XXGPMS_PROJECT_COSTS
            SET
              EVENT_ATTR = P_CONTRACT_NUMBER
                           || ' - '
                           || TO_NUMBER(
                SUBSTR( P_EVENT_NO_RET_TMP, 2, LENGTH(P_EVENT_NO_RET_TMP) - 2 )
              )
            WHERE
              EVENT_ATTR IS NOT NULL;
          ELSE
            L_URL := INSTANCE_URL
                     || '/fscmRestApi/resources/11.13.18.05/projectBillingEvents/'
                     || I.EVENT_ID;
            WIP_DEBUG (3, 7210, L_URL, '');
            L_ENVELOPE := '{"BillTrnsAmount" : '
                          || I.BILL_TRNS_AMOUNT
                          || '}';
            WIP_DEBUG (3, 7211, L_ENVELOPE, '');
            APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
            APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/json';
            L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST (
              P_URL => L_URL,
              P_HTTP_METHOD => 'PATCH',
 --p_username => g_username,
 --p_password => g_password,
 --   P_CREDENTIAL_STATIC_ID => 'GPMS_DEV',
              P_SCHEME => 'OAUTH_CLIENT_CRED',
              P_BODY => L_ENVELOPE
            );
            WIP_DEBUG (3, 7212, L_RESPONSE_CLOB, '');
            WIP_DEBUG (3, 7213, 'Response of PATCHING Event for Agreement '
                                ||P_CONTRACT_NUMBER
                                ||' Project '
                                ||I.PROJECT_NUMBER
                                ||' WIP Category '
                                ||I.WIP_CATEGORY
                                ||' Task Number '
                                ||I.TASK_NUMBER
                                ||' is '
                                ||APEX_WEB_SERVICE.G_STATUS_CODE, '');
            IF APEX_WEB_SERVICE.G_STATUS_CODE IN (200, 201) THEN
              LV_RESPONSE := LV_RESPONSE * 1;
            ELSE
              LV_RESPONSE := 0;
              EXIT;
            END IF;
            UPDATE XXGPMS_PROJECT_COSTS
            SET
              EVENT_ATTR = P_CONTRACT_NUMBER
                           || ' - '
                           || I.EVENT_NUM
            WHERE
              EVENT_ATTR IS NOT NULL;
          END IF;
        END IF;
      END LOOP;
      WIP_DEBUG (3, 7213, 'Final Response Status after Event Loop Exiting is: '
                          ||LV_RESPONSE, '');
    EXCEPTION
      WHEN OTHERS THEN
        EVENT_FOUND_FLAG := 'N';
        P_BILL_TRANS_AMOUNT := 0;
    END;
 -- Retrive Project information
    -- SELECT
    --   DISTINCT PROJECT_NAME,
    --   PROJECT_ID,
    --   BU_NAME,
    --   BU_ID INTO P_PROJECT_NAME,
    --   P_PROJECT_ID,
    --   P_BU_NAME,
    --   P_BU_ID
    -- FROM
    --   XXGPMS_PROJECT_COSTS
    -- WHERE
    --   PROJECT_NUMBER = NVL(P_PROJECT_NUMBER, PROJECT_NUMBER)
    --   AND CONTRACT_NUMBER = NVL(P_CONTRACT_NUMBER, CONTRACT_NUMBER)
    --   AND SESSION_ID = V ('APP_SESSION')
    --   AND ROWNUM = 1;
    SELECT
      CONTRACT_ID,
      PROJECT_NAME,
      PROJECT_ID,
      BU_NAME,
      BUSINESS_UNIT_ID INTO P_CONTRACT_ID,
      P_PROJECT_NAME,
      P_PROJECT_ID,
      P_BU_NAME,
      P_BU_ID
    FROM
      XXGPMS_PROJECT_CONTRACT
    WHERE
      PROJECT_NUMBER = NVL(P_PROJECT_NUMBER, PROJECT_NUMBER)
      AND CONTRACT_NUMBER = NVL(P_CONTRACT_NUMBER, CONTRACT_NUMBER)
      AND SESSION_ID = V ('APP_SESSION')
      AND ROWNUM = 1;
 -- COMMENTING THE BELOW CODE AS NO LONGER REQUIRED
 --     BEGIN
 --       CMTE_APPROVAL_REQUIRED_FLAG := 'N';
 --       CMTE_APPROVAL_ADJUSTMENT := 0;
 --       SELECT
 --         SUM(NVL(PROJECT_BILL_RATE_AMT,
 --         0)) INTO P_CMTE_BILL_RATE_AMT
 --       FROM
 --         XXGPMS_PROJECT_COSTS
 --       WHERE
 --         PROJECT_NUMBER = NVL(P_PROJECT_NUMBER,
 --         PROJECT_NUMBER)
 --         AND CONTRACT_NUMBER = NVL(P_CONTRACT_NUMBER,
 --         CONTRACT_NUMBER)
 --         AND SESSION_ID = V ('APP_SESSION')
 --         AND REALIZED_BILL_RATE_ATTR <> 0;
 --       SELECT
 --         SUM(NVL(BILL_TRNS_AMOUNT,
 --         0)) INTO P_CMTE_EVNT_RATE_AMT
 --       FROM
 --         XXGPMS_PROJECT_EVENTS
 --       WHERE
 --         PROJECT_NUMBER = NVL(P_PROJECT_NUMBER,
 --         PROJECT_NUMBER)
 --         AND CONTRACT_NUMBER = NVL(P_CONTRACT_NUMBER,
 --         CONTRACT_NUMBER)
 --         AND SESSION_ID = V ('APP_SESSION')
 --         AND NVL(INVOICEDSTATUS,
 --         'Uninvoiced') <> 'Fully Invoiced';
 --     EXCEPTION
 --       WHEN NO_DATA_FOUND THEN
 --         P_CMTE_EVNT_RATE_AMT := '0';
 --         P_CMTE_BILL_RATE_AMT := 0;
 --       WHEN OTHERS THEN
 --         P_CMTE_EVNT_RATE_AMT := '0';
 --         P_CMTE_BILL_RATE_AMT := 0;
 --     END;
 --     IF P_CMTE_BILL_RATE_AMT > 0 AND P_CMTE_EVNT_RATE_AMT > 0 THEN
 --       CMTE_ADJ_PCT := (P_CMTE_BILL_RATE_AMT - P_CMTE_EVNT_RATE_AMT) * 100 / P_CMTE_BILL_RATE_AMT;
 --       IF ( CMTE_ADJ_PCT < -15
 --       OR CMTE_ADJ_PCT > 15 ) THEN
 --         CMTE_APPROVAL_REQUIRED_FLAG := 'Y';
 --         CMTE_APPROVAL_ADJUSTMENT := P_CMTE_BILL_RATE_AMT - P_CMTE_EVNT_RATE_AMT;
 --       ELSE
 --         CMTE_APPROVAL_REQUIRED_FLAG := 'N';
 --         CMTE_APPROVAL_ADJUSTMENT := P_CMTE_BILL_RATE_AMT - P_CMTE_EVNT_RATE_AMT;
 --       END IF;
 --     END IF;
 --  -- Retrive Project information
 --     SELECT
 --       DISTINCT PROJECT_NAME,
 --       PROJECT_ID,
 --       BU_NAME,
 --       BU_ID INTO P_PROJECT_NAME,
 --       P_PROJECT_ID,
 --       P_BU_NAME,
 --       P_BU_ID
 --     FROM
 --       XXGPMS_PROJECT_COSTS
 --     WHERE
 --       PROJECT_NUMBER = NVL(P_PROJECT_NUMBER,
 --       PROJECT_NUMBER)
 --       AND CONTRACT_NUMBER = NVL(P_CONTRACT_NUMBER,
 --       CONTRACT_NUMBER)
 --       AND SESSION_ID = V ('APP_SESSION')
 --       AND ROWNUM = 1;
 --  /* Set the Project Level DFF */
 --     L_URL := INSTANCE_URL
 --       || ':443/fscmService/ProjectDefinitionPublicServiceV2';
 --     WIP_DEBUG (3, 7200, 'L_URL '||L_URL, '');
 --     L_SENVELOPE := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/projects/foundation/projectDefinition/publicService/maintainProjectV2/types/" xmlns:main="http://xmlns.oracle.com/apps/projects/foundation/projectDefinition/publicService/maintainProjectV2/" xmlns:proj="http://xmlns.oracle.com/apps/projects/foundation/projectDefinition/flex/ProjectClassCodeDff/" xmlns:proj1="http://xmlns.oracle.com/apps/projects/foundation/projectDefinition/flex/ProjectDff/">
 --                               <soapenv:Header/>
 --                                <soapenv:Body>
 -- 		                <typ:mergeProjectData>
 -- 				 <typ:Project>
 -- 				    <main:ProjectId>'
 --       || P_PROJECT_ID
 --       || '</main:ProjectId>
 -- 				    <main:ProjectDff>
 -- 				       <proj1:ProjectId>'
 --       || P_PROJECT_ID
 --       || '</proj1:ProjectId>
 -- 				       <proj1:billingCommitteeApprovalRequir>'
 --       || CMTE_APPROVAL_REQUIRED_FLAG
 --       || '</proj1:billingCommitteeApprovalRequir>
 -- 				       <proj1:writeOffAmount>'
 --       || CMTE_APPROVAL_ADJUSTMENT
 --       || '</proj1:writeOffAmount>
 -- 				       <proj1:writeOffReason>'
 --       || P_JUSTIFICATION
 --       || '</proj1:writeOffReason>
 -- 				    </main:ProjectDff>
 -- 				 </typ:Project>
 -- 			       </typ:mergeProjectData>
 -- 			      </soapenv:Body>
 -- 		             </soapenv:Envelope>';
 --       WIP_DEBUG (3, 7205, 'L_SENVELOPE '||L_SENVELOPE, '');
 --  --l_sresponse_xml := apex_web_service.make_request ( p_url => l_url, p_version => l_sversion, p_action => 'mergeProjectData', p_envelope => l_senvelope, p_username => g_username, p_password => g_password );
 --     L_SRESPONSE_XML := APEX_WEB_SERVICE.MAKE_REQUEST ( P_URL => L_URL, P_VERSION => L_SVERSION, P_ACTION => 'mergeProjectData', P_ENVELOPE => L_SENVELOPE
 --  -- ,P_CREDENTIAL_STATIC_ID => 'GPMS_DEV'
 --     );
 /*   End Project DFF Update */
 /* Generate Invoice Web Service Call */
    WIP_DEBUG (3, 7219, 'lv_response '
                                                                                             ||LV_RESPONSE, '');
    IF LV_RESPONSE <> 0 THEN
      P_INVOICE_DATE := P_BILL_THRU_DATE;
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Authorization';
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'Bearer '
                                                      || V ('G_SAAS_ACCESS_TOKEN');
      L_URL := INSTANCE_URL
               || ':443/fscmService/ErpIntegrationService';
      WIP_DEBUG (3, 7220, L_URL, '');
      WIP_DEBUG (3, 7220.5, APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE, '');
      L_SENVELOPE := q'#<?xml version="1.0" encoding="UTF-8"?>#';
      L_SENVELOPE := L_SENVELOPE
                     ||'<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/">
		              <soapenv:Header/>
			       <soapenv:Body>
			        <typ:submitESSJobRequest>
				 <typ:jobPackageName>oracle/apps/ess/projects/billing/workarea/invoice</typ:jobPackageName>
				 <typ:jobDefinitionName>InvoiceGenerationJob</typ:jobDefinitionName>
				 <typ:paramList>'
                     || P_BU_NAME
                     || '</typ:paramList>
				 <typ:paramList>'
                     || P_BU_ID
                     || '</typ:paramList>
				 <typ:paramList>EX</typ:paramList>
				 <typ:paramList>Y</typ:paramList>
				 <typ:paramList>Y</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>'
                     || P_CONTRACT_ID
                     || '</typ:paramList>
				 <typ:paramList>'
                     || P_CONTRACT_NUMBER
                     || '</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>'
                     || CASE
        WHEN P_PROJECT_NUMBER IS NOT NULL THEN
          P_PROJECT_ID
        ELSE
          NULL
      END
      || '</typ:paramList>
				 <typ:paramList>'
      || CASE
        WHEN P_PROJECT_NUMBER IS NOT NULL THEN
          REPLACE(P_PROJECT_NAME, '&', '&amp;')
        ELSE
          NULL
      END
      || '</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>'
      ||TO_CHAR(P_BILL_FROM_DATE, 'YYYY-MM-DD')
        ||'</typ:paramList>
				 <typ:paramList>'
        || TO_CHAR(P_BILL_THRU_DATE, 'YYYY-MM-DD')
           || '</typ:paramList>
				 <typ:paramList>N</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>'
           || TO_CHAR(P_INVOICE_DATE, 'YYYY-MM-DD')
              || '</typ:paramList>
				 <typ:paramList>N</typ:paramList>
				 <typ:paramList>SUMMARY</typ:paramList>
				 <typ:paramList>N</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>#NULL</typ:paramList>
				 <typ:paramList>1</typ:paramList>
			       </typ:submitESSJobRequest>
			      </soapenv:Body>
			     </soapenv:Envelope>';
      WIP_DEBUG (3, 7221, L_SENVELOPE, '');
      L_SRESPONSE_XML := APEX_WEB_SERVICE.MAKE_REQUEST (
        P_URL => L_URL,
        P_VERSION => L_SVERSION,
        P_ACTION => 'submitESSJobRequest',
        P_ENVELOPE => L_SENVELOPE
 -- ,P_SCHEME    => 'OAUTH_CLIENT_CRED'
 -- ,P_CREDENTIAL_STATIC_ID => 'GPMS_DEV'
 -- ,p_username => g_username
 -- ,p_password => g_password
      );
      WIP_DEBUG (3, 7222, L_SRESPONSE_XML.GETCLOBVAL(), '');
      IF APEX_WEB_SERVICE.G_STATUS_CODE IN (200, 201) THEN
        LS_RESPONSE_CLOB := L_SRESPONSE_XML.GETCLOBVAL();
        WITH T AS (
          SELECT
            LS_RESPONSE_CLOB AS K
          FROM
            DUAL
        )
        SELECT
          SUBSTR(ACTUAL_STRING, START_COL, END_COL-START_COL) INTO L_JOB_ID
        FROM
          (
            SELECT
              INSTR(K, '<result xmlns="http://xmlns.oracle.com/apps/financials/commonModules/shared/model/erpIntegrationService/types/">')+112 START_COL,
              INSTR(K, '</result>')                                                                                                            END_COL,
              K                                                                                                                                ACTUAL_STRING
            FROM
              T
          );
        WIP_DEBUG (3, 7223, L_JOB_ID, '');
        DBMS_SESSION.SLEEP(25);
        UPDATE_INVOICE_HEADER_DFFS (P_CONTRACT_ID, L_JOB_ID, P_TOTAL_UP_DOWN, V_RESPONSE_CODE);
 -- final step is to submit the invoice
        SUBMIT_INVOICE;
      END IF;
      APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE ();
 -- Invoke Save Session
      XX_PROCESS_HOLD (P_PROJECT_NUMBER);
    END IF;
  END GENERATE_DRAFT_INVOICE;
  PROCEDURE TAG_EVENTS (
    P_PROJECT_NUMBER IN VARCHAR2,
    P_EXPENDITURE_ITEM_LIST IN VARCHAR2,
    P_EVENT_NUM_LIST IN VARCHAR2,
    P_SEL_AMT IN NUMBER
  ) IS
    P_CONTRACT_NUMBER      VARCHAR2(100);
    P_CONTRACT_LINE_NUMBER VARCHAR2(50);
    INPUT_STR              VARCHAR2(32000);
    TEMP_STR               VARCHAR2(32000);
    EXP_ID                 VARCHAR2(100);
    P_BILL_TRNS_AMOUNT     NUMBER;
    VAR1                   NUMBER;
    RETCODE                INT;
  BEGIN
    WIP_DEBUG (3, 8000, P_EVENT_NUM_LIST, '');
    SELECT
      CONTRACT_NUMBER,
      BILL_TRNS_AMOUNT,
      CONTRACT_LINE_NUMBER INTO P_CONTRACT_NUMBER,
      P_BILL_TRNS_AMOUNT,
      P_CONTRACT_LINE_NUMBER
    FROM
      XXGPMS_PROJECT_EVENTS
    WHERE
      EVENT_NUM = SUBSTR( P_EVENT_NUM_LIST, 2, LENGTH(P_EVENT_NUM_LIST) - 2 );
 -- UPDATE xxgpms_project_costs
 --     SET event_attr = null
 --   WHERE event_attr = p_contract_number || '-' || substr(p_event_num_list,2,length(p_event_num_list)-2);
    RETCODE := WIP_TAG_ADJUSTMENT ( P_EXPENDITURE_ITEM_LIST, P_PROJECT_NUMBER, 0, P_BILL_TRNS_AMOUNT, P_SEL_AMT, 'Y', '');
    INPUT_STR := P_EXPENDITURE_ITEM_LIST;
    VAR1 := INSTR(INPUT_STR, '-', 1, 2);
    WHILE (VAR1 > 0) LOOP
      TEMP_STR := SUBSTR(INPUT_STR, 2, VAR1 - 2);
      EXP_ID := TEMP_STR;
      UPDATE XXGPMS_PROJECT_COSTS
      SET
        EVENT_ATTR = P_CONTRACT_NUMBER
                     || '-'
                     || P_CONTRACT_LINE_NUMBER
                     || '-'
                     || SUBSTR(
          P_EVENT_NUM_LIST,
          2,
          LENGTH(P_EVENT_NUM_LIST) - 2
        )
      WHERE
        EXPENDITURE_ITEM_ID = EXP_ID;
      INPUT_STR := SUBSTR(INPUT_STR, VAR1, 32000);
      VAR1 := INSTR(INPUT_STR, '-', 1, 2);
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      WIP_DEBUG (3, 8100, 'Error Selecting Event', '');
  END TAG_EVENTS;
  FUNCTION GET_PROJECT_DETAILS (
    P_SESSION_ID IN NUMBER,
    P_PROJECT_NUMBER IN VARCHAR2,
    O_PROJECT_NAME OUT VARCHAR2,
    O_BU_NAME OUT VARCHAR2,
    O_LEGAL_ENTITY_NAME OUT VARCHAR2,
    O_CURRENCY_CODE OUT VARCHAR2,
    O_CUSTOMER_NAME OUT VARCHAR2,
    O_RETAINER_BALANCE OUT VARCHAR2,
    O_CONTRACT_ID OUT VARCHAR2
  ) RETURN NUMBER IS
  BEGIN WIP_DEBUG (1, 9000, P_PROJECT_NUMBER, '');
  BEGIN
    SELECT
      PROJECT_NAME,
      BU_NAME,
      LEGAL_ENTITY_NAME,
      CURRENCY_CODE,
      CUSTOMER_NAME,
      NVL(RETAINER_BALANCE, 0) RETAINER_BALANCE,
      CONTRACT_ID INTO O_PROJECT_NAME,
      O_BU_NAME,
      O_LEGAL_ENTITY_NAME,
      O_CURRENCY_CODE,
      O_CUSTOMER_NAME,
      O_RETAINER_BALANCE,
      O_CONTRACT_ID
    FROM
      XXGPMS_PROJECT_CONTRACT
    WHERE
      SESSION_ID = V ('APP_SESSION')
      AND PROJECT_NUMBER = NVL(P_PROJECT_NUMBER, PROJECT_NUMBER) FETCH FIRST ROW ONLY;
    WIP_DEBUG (1, 9000, O_CURRENCY_CODE, '');
  EXCEPTION
    WHEN OTHERS THEN
      WIP_DEBUG (1, 9001, 'retcode 1', SQLERRM);
      RETURN 1;
      END;
    RETURN 0;
  END GET_PROJECT_DETAILS; --- CODE TO POPULATE THE RATES ON THE PROJECT COSTS TO DEFAULT VALUES
 --  ADDED BY EMMANUEL
  PROCEDURE POPULATE_RATES_ONLOAD (
    P_PROJECT_ID NUMBER,
    P_TASK_ID NUMBER DEFAULT NULL,
    P_WIP_CATEGORY VARCHAR2 DEFAULT NULL,
    P_PROJECT_NUMBER VARCHAR2 DEFAULT NULL,
    P_CONTRACT_ID NUMBER
  ) IS
    L_URL                        VARCHAR2(4000) := P_URL;
    L_VERSION                    VARCHAR2(10) := 1.2;
    L_RESPONSE_CLOB              CLOB;
    L_ENVELOPE                   VARCHAR2(32000);
    P_EXP_AMT                    NUMBER;
    P_INTERNAL_COMMENT           VARCHAR2(1000);
    P_NARRATIVE_BILLING_OVERFLOW VARCHAR2(1000);
    P_EVENT_ATTR                 VARCHAR2(50);
    P_STANDARD_BILL_RATE_ATTR    NUMBER;
    P_PROJECT_BILL_RATE_ATTR     NUMBER;
    P_REALIZED_BILL_RATE_ATTR    NUMBER;
    P_BILLABLE_FLAG              VARCHAR2(10);
    P_EXPENDITURE_ITEM_ID        NUMBER;
    V_STATUSCODE                 NUMBER;
    V_VALUE                      NUMBER;
    L_XML_RESPONSE               XMLTYPE;
    L_CLOB_REPORT_RESPONSE       CLOB;
    L_CLOB_REPORT_DECODE         CLOB;
    L_CLOB_TEMP                  CLOB;
    V_ATTR1                      VARCHAR2(1000);
    V_ATTR2                      VARCHAR2(1000);
    L_STANDARD_RATE              NUMBER;
    L_AGREEMENT_RATE             NUMBER;
  BEGIN
    WIP_DEBUG ( 3, 9000, 'Populate Rates Onload for Project Number: '
                         || P_PROJECT_NUMBER, ' PROJECT ID '
                                              || P_PROJECT_ID
                                              || ' TASK '
                                              || P_TASK_ID
                                              || ' WIP CATEGORY: '
                                              || P_WIP_CATEGORY );
    L_VERSION := '1.2';
 -- Call to the OTBI to fetch the projects rates
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_RESPONSE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_DECODE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_TEMP, TRUE);
    L_ENVELOPE := '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">
			<soap:Header/>
			   <soap:Body>
				  <pub:runReport>
					 <pub:reportRequest>
					   <pub:attributeFormat>xml</pub:attributeFormat>
						 <pub:parameterNameValues>
							<pub:item>
								<pub:name>P_PROJECT_ID</pub:name>
								<pub:values>
									<pub:item>'
                  || P_PROJECT_ID
                  || '</pub:item>
								</pub:values>
							</pub:item>
                            <pub:item>
								<pub:name>P_CONTRACT_ID</pub:name>
								<pub:values>
									<pub:item>'
                  || P_CONTRACT_ID
                  || '</pub:item>
								</pub:values>
							</pub:item>
						</pub:parameterNameValues>
					   <pub:reportAbsolutePath>/Custom/Projects/Project Billing/Project Costs Report.xdo</pub:reportAbsolutePath>
					   <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
					 </pub:reportRequest>
					 <pub:appParams></pub:appParams>
				  </pub:runReport>
			   </soap:Body>
			</soap:Envelope>';
    WIP_DEBUG (3, 9000, 'Populate Rates Envelope ', L_ENVELOPE);
    WIP_DEBUG (3, 9001, 'Populate Rates URL ', L_URL);
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Authorization';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'Bearer '
                                                    || V ('G_SAAS_ACCESS_TOKEN');
    WIP_DEBUG ( 3, 9002, 'Populate Rates Bearer Token ', 'Bearer '
                                                         || V ('G_SAAS_ACCESS_TOKEN') );
 -- l_xml_response := apex_web_service.make_request ( p_url => l_url, p_version => l_version, p_action => 'runReport', p_envelope => l_envelope, p_username => g_username, p_password => g_password );
    L_XML_RESPONSE := APEX_WEB_SERVICE.MAKE_REQUEST ( P_URL => L_URL, P_VERSION => L_VERSION, P_ACTION => 'runReport', P_ENVELOPE => L_ENVELOPE
 -- ,P_CREDENTIAL_STATIC_ID => 'GPMS_DEV'
    );
    WIP_DEBUG ( 3, 9003, 'Populate Rates Web Service Response', L_XML_RESPONSE.GETCLOBVAL () );
    L_CLOB_REPORT_RESPONSE := APEX_WEB_SERVICE.PARSE_XML_CLOB ( P_XML => L_XML_RESPONSE, P_XPATH => ' //runReportResponse/runReportReturn/reportBytes', P_NS => ' xmlns="http://xmlns.oracle.com/oxp/service/PublicReportService"' );
    L_CLOB_TEMP := SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1, INSTR( SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1 ), '</ns2:report' ) - 1 );
    L_CLOB_REPORT_RESPONSE := L_CLOB_TEMP;
    L_CLOB_REPORT_DECODE := BASE64_DECODE_CLOB (L_CLOB_REPORT_RESPONSE);
    COMMIT;
 -- End
    WIP_DEBUG ( 3, 9004, 'Populate Rates Web Service Response Decoded', L_CLOB_REPORT_DECODE );
    INSERT INTO XXGPMS_PROJECT_RATES (
      SESSION_ID,
      USER_EMAIL,
      CREATED_DATE,
      PROJECT_ID,
      PROJECT_NUMBER,
      TASK_ID,
      PROJ_ELEMENT_ID,
      CARRYING_OUT_ORGANIZATION_ID,
      ATTRIBUTE_NUMBER1,
      ATTRIBUTE_NUMBER2,
      ATTRIBUTE_NUMBER3,
      PERSON_ID,
      START_DATE_ACTIVE,
      INCURRED_BY_PERSON_ID,
      END_DATE_ACTIVE,
      RATE_UNIT,
      RATE,
      RATE_SCHEDULE_ID,
      EXPENDITURE_TYPE_ID,
      PERSON_JOB_ID,
      RAW_COST_RATE, -- EXPENDITURE_ITEM_DATE,
      MARKUP_PERCENTAGE,
      JOB_ID,
      STANDARD_RATE,
      AGREEMENT_RATE,
      EXPENDITURE_ITEM_ID
    )
      SELECT
        V ('APP_SESSION'),
        V('G_SAAS_USER'),
        SYSTIMESTAMP,
        PROJECT_ID,
        PROJECT_NUMBER,
        TASK_ID,
        PROJ_ELEMENT_ID,
        CARRYING_OUT_ORGANIZATION_ID,
        ATTRIBUTE_NUMBER1,
        ATTRIBUTE_NUMBER2,
        ATTRIBUTE_NUMBER3,
        PERSON_ID,
        START_DATE_ACTIVE,
        INCURRED_BY_PERSON_ID,
        END_DATE_ACTIVE,
        RATE_UNIT,
        RATE,
        RATE_SCHEDULE_ID,
        EXPENDITURE_TYPE_ID,
        PERSON_JOB_ID,
        RAW_COST_RATE, -- EXPENDITURE_ITEM_DATE,
        MARKUP_PERCENTAGE,
        JOB_ID,
        STANDARD_RATE,
        AGREEMENT_RATE,
        EXPENDITURE_ITEM_ID
      FROM
        XMLTABLE( '/DATA_DS/G_RATES' PASSING XMLTYPE (L_CLOB_REPORT_DECODE) COLUMNS PROJECT_ID PATH 'PROJECT_ID',
        PROJECT_NUMBER PATH 'PROJECT_NUMBER',
        TASK_ID PATH 'TASK_ID',
        PROJ_ELEMENT_ID PATH 'PROJ_ELEMENT_ID',
        CARRYING_OUT_ORGANIZATION_ID PATH 'CARRYING_OUT_ORGANIZATION_ID',
        ATTRIBUTE_NUMBER1 PATH 'ATTRIBUTE_NUMBER1',
        ATTRIBUTE_NUMBER2 PATH 'ATTRIBUTE_NUMBER2',
        ATTRIBUTE_NUMBER3 PATH 'ATTRIBUTE_NUMBER3',
        PERSON_ID PATH 'PERSON_ID',
        START_DATE_ACTIVE PATH 'START_DATE_ACTIVE',
        INCURRED_BY_PERSON_ID PATH 'INCURRED_BY_PERSON_ID',
        END_DATE_ACTIVE PATH 'END_DATE_ACTIVE',
        RATE_UNIT PATH 'RATE_UNIT',
        RATE PATH 'RATE',
        RATE_SCHEDULE_ID PATH 'RATE_SCHEDULE_ID',
        EXPENDITURE_TYPE_ID PATH 'EXPENDITURE_TYPE_ID',
        PERSON_JOB_ID PATH 'PERSON_JOB_ID',
        RAW_COST_RATE PATH 'RAW_COST_RATE', -- EXPENDITURE_ITEM_DATE PATH 'EXPENDITURE_ITEM_DATE'
        MARKUP_PERCENTAGE PATH 'MARKUP_PERCENTAGE',
        JOB_ID PATH 'JOB_ID',
        STANDARD_RATE PATH 'STANDARD_RATE',
        AGREEMENT_RATE PATH 'AGREEMENT_RATE',
        EXPENDITURE_ITEM_ID PATH 'EXPENDITURE_ITEM_ID' )                    XT;
    COMMIT;
    WIP_DEBUG ( 2, 9005, 'Populate Rates, Insert Complete!', '' );
 -- Find all the expenditure costs that needs the rates populated
    FOR I IN (
      SELECT
        DISTINCT EXPENDITURE_ITEM_ID,
        PROJECT_ID,
        WIP_CATEGORY,
        TASK_ID,
        INCURRED_BY_PERSON_ID,
        EXPENDITURE_ITEM_DATE,
        JOB_ID
      FROM
        XXGPMS_PROJECT_COSTS
      WHERE
        SESSION_ID = V ('APP_SESSION')
        AND PROJECT_ID = P_PROJECT_ID
        AND (NVL(STANDARD_BILL_RATE_ATTR, 0) = 0
        OR NVL(PROJECT_BILL_RATE_ATTR, 0) = 0)
    ) LOOP
 --- Update Bill Rate DFF -------
 -- WIP_DEBUG (
 --   2,
 --   9010,
 --   'Populate Rates, Entered into the Loop, Data Found to be updated ' || I.EXPENDITURE_ITEM_ID||' '||I.PROJECT_ID||' '||I.WIP_CATEGORY||' '||I.TASK_ID||' '||I.INCURRED_BY_PERSON_ID||' '||I.EXPENDITURE_ITEM_DATE,
 --   ''
 -- );
 -- -- Get the value as per WIP Category
 --   begin
 --     select attribute_number1
 --     into   v_attr1
 --     from   xxgpms_project_rates
 --     where  project_id = i.project_id
 --     and    task_id    = i.task_id
 --     and    incurred_by_person_id = i.incurred_by_person_id
 --     and    i.expenditure_item_date between start_date_active and end_date_active;
 --   exception
 --     when others
 --     then
 --       v_attr1 := null;
 --   end;
 --   WIP_DEBUG (
 --   2,
 --   9011,
 --   'v_attr1: '|| I.EXPENDITURE_ITEM_ID||' PERSON ID '||I.INCURRED_BY_PERSON_ID||' JOB ID '||I.JOB_ID||' EXP DATE '||I.EXPENDITURE_ITEM_DATE||' '||v_attr1,
 --   ''
 -- );
 --     begin
 --     select attribute_number2
 --     into   v_attr2
 --     from   xxgpms_project_rates
 --     where  project_id = i.project_id
 --     and    task_id    = i.task_id
 --     and    person_job_id = i.job_id;
 --     -- and    i.expenditure_item_date between start_date_active and end_date_active;
 --   exception
 --     when others
 --     then
 --       v_attr2 := null;
 --   end;
 --   WIP_DEBUG (
 --   2,
 --   9012,
 --   'v_attr2: '|| I.EXPENDITURE_ITEM_ID||' PERSON ID '||I.INCURRED_BY_PERSON_ID||' JOB ID '||I.JOB_ID||' EXP DATE '||I.EXPENDITURE_ITEM_DATE||' '||v_attr2,
 --   ''
 -- );
 -- begin
 --   V_VALUE := NULL;
 -- if i.wip_category = 'Labor' and v_attr1 is not null
 -- then
 --   select nvl(rate,markup_percentage*raw_cost_rate)
 --   into   v_value
 --   from   xxgpms_project_rates
 --   where  project_id = i.project_id
 --   and    task_id = i.task_id
 --   and    rate_schedule_id = v_attr1
 --   and    incurred_by_person_id = i.incurred_by_person_id;
 -- elsif i.wip_category = 'Labor' and v_attr1 is null and v_attr2 is not null
 -- then
 --   select nvl(rate,markup_percentage*raw_cost_rate)
 --   into   v_value
 --   from   xxgpms_project_rates
 --   where  project_id = i.project_id
 --   and    task_id = i.task_id
 --   and    rate_schedule_id = v_attr2
 --   and    person_job_id = i.job_id;
 -- elsif i.wip_category <> 'Labor'
 -- then
 --   select nvl(rate,markup_percentage*raw_cost_rate)
 --   into   v_value
 --   from   xxgpms_project_rates
 --   where  project_id = i.project_id
 --   and    task_id = i.task_id
 --   and    rate_schedule_id = attribute_number3
 --   and    nvl(incurred_by_person_id,'-999') = nvl(i.incurred_by_person_id,'-999');
 -- end if;
 -- exception
 --   when others then
 --     v_value := null;
 -- end;
      BEGIN
        SELECT
          NVL(STANDARD_RATE, 0),
          NVL(AGREEMENT_RATE, 0) INTO L_STANDARD_RATE,
          L_AGREEMENT_RATE
        FROM
          XXGPMS_PROJECT_RATES
        WHERE
          EXPENDITURE_ITEM_ID = I.EXPENDITURE_ITEM_ID
          AND SESSION_ID = V ('APP_SESSION');
      EXCEPTION
        WHEN OTHERS THEN
          WIP_DEBUG ( 2, 9888, 'Error : '
                               || SQLERRM, '');
          L_STANDARD_RATE := 0;
          L_AGREEMENT_RATE := 0;
      END;
 --   L_STANDARD_RATE := TO_CHAR(L_STANDARD_RATE,'9999999990.00');
 --   L_AGREEMENT_RATE := TO_CHAR(L_AGREEMENT_RATE,'9999999990.00');
      WIP_DEBUG ( 2, 9013, 'Populate Rates, Value Returned '
                           ||TO_CHAR(L_STANDARD_RATE, '9999990.99')
                             ||' '
                             ||TO_CHAR(L_AGREEMENT_RATE, '9999990.99')
                               ||' for '
                               || I.EXPENDITURE_ITEM_ID
                               ||' '
                               ||I.PROJECT_ID
                               ||' '
                               ||I.WIP_CATEGORY
                               ||' '
                               ||I.TASK_ID
                               ||' '
                               ||I.INCURRED_BY_PERSON_ID
                               ||' '
                               ||I.EXPENDITURE_ITEM_DATE, '' );
      L_URL := INSTANCE_URL
               || '/fscmRestApi/resources/11.13.18.05/projectExpenditureItems/'
               || I.EXPENDITURE_ITEM_ID
               || '/child/ProjectExpenditureItemsDFF/'
               || I.EXPENDITURE_ITEM_ID;
      L_ENVELOPE := '{
            "standardBillRate": '
                    || TO_CHAR(L_STANDARD_RATE, '9999990.99')
                       || '
            ,"projectBillRate": '
                       || TO_CHAR(L_AGREEMENT_RATE, '9999990.99')
                          || '
            ,"realizedBillRate": '
                          || TO_CHAR(L_AGREEMENT_RATE, '9999990.99')
                             || '
            }';
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/json';
      WIP_DEBUG (3, 9014, L_URL, '');
      WIP_DEBUG (3, 9015, I.EXPENDITURE_ITEM_ID
                          ||' for Envelope: '
                          ||L_ENVELOPE, '');
 -- APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Authorization';
 -- APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'Bearer ' || v ('G_SAAS_ACCESS_TOKEN');
      L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST (
        P_URL => L_URL,
        P_HTTP_METHOD => 'PATCH',
 --  P_CREDENTIAL_STATIC_ID => 'GPMS_DEV',
 -- p_token_url => v ('G_SAAS_ACCESS_TOKEN'),
 -- P_CREDENTIAL_STATIC_ID => 'GPMS_DEV',
 --  p_username => g_username,
 --  p_password => g_password,
        P_SCHEME => 'OAUTH_CLIENT_CRED',
        P_BODY => L_ENVELOPE
      );
      APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE ();
      WIP_DEBUG (2, 9050, I.EXPENDITURE_ITEM_ID, L_RESPONSE_CLOB);
      V_STATUSCODE := APEX_WEB_SERVICE.G_STATUS_CODE;
 -- UPDATE THE TABLE DATA IF THE WEBSERVICE RESPONSE IS SUCCESS
      WIP_DEBUG ( 2, 9016, 'webservice response for populate_rates_onload '
                           || I.EXPENDITURE_ITEM_ID
                           || ' '
                           || V_STATUSCODE
                           ||' Response: '
                           ||APEX_WEB_SERVICE.G_STATUS_CODE, '' );
      IF V_STATUSCODE IN (200, 201) THEN
        UPDATE XXGPMS_PROJECT_COSTS
        SET
          STANDARD_BILL_RATE_ATTR = L_STANDARD_RATE,
          PROJECT_BILL_RATE_ATTR = L_AGREEMENT_RATE,
          REALIZED_BILL_RATE_ATTR = L_AGREEMENT_RATE,
          STANDARD_BILL_RATE_AMT = TO_CHAR(
            (L_STANDARD_RATE * QUANTITY),
            '9999999990.00'
          ),
          PROJECT_BILL_RATE_AMT = TO_CHAR(
            (L_AGREEMENT_RATE * QUANTITY),
            '9999999990.00'
          ),
          REALIZED_BILL_RATE_AMT = TO_CHAR(
            (L_AGREEMENT_RATE * QUANTITY),
            '9999999990.00'
          )
        WHERE
          EXPENDITURE_ITEM_ID = I.EXPENDITURE_ITEM_ID;
      END IF;
    END LOOP;
    WIP_DEBUG ( 2, 9350, 'End Populate Rates Onload for Project: '
                         || P_PROJECT_NUMBER, '' );
  END POPULATE_RATES_ONLOAD; ---
  PROCEDURE GET_USER_DETAILS (
    USER_EMAIL IN VARCHAR2
  ) IS
    L_URL                  VARCHAR2(4000) := P_URL;
    L_VERSION              VARCHAR2(1000) := '1.2';
    L_ENVELOPE             VARCHAR2(10000);
    L_XML_RESPONSE         XMLTYPE;
    L_CLOB_REPORT_RESPONSE CLOB;
    L_CLOB_REPORT_DECODE   CLOB;
    L_CLOB_TEMP            CLOB;
    L_OTBI_FLAG            VARCHAR2(1) := 'N';
  BEGIN
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_RESPONSE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_DECODE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_TEMP, TRUE);
    L_ENVELOPE := '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">
			<soap:Header/>
			   <soap:Body>
				  <pub:runReport>
					 <pub:reportRequest>
					   <pub:attributeFormat>xml</pub:attributeFormat>
						 <pub:parameterNameValues>
							<pub:item>
								<pub:name>USER_EMAIL</pub:name>
								<pub:values>
									<pub:item>'
                  || USER_EMAIL
                  || '</pub:item>
								</pub:values>
							</pub:item>
						</pub:parameterNameValues>
					   <pub:reportAbsolutePath>/Custom/Projects/Project Billing/Project Costs Report.xdo</pub:reportAbsolutePath>
					   <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
					 </pub:reportRequest>
					 <pub:appParams></pub:appParams>
				  </pub:runReport>
			   </soap:Body>
			</soap:Envelope>';
    WIP_DEBUG (3, 6000, 'Users Envelope ', L_ENVELOPE);
 -- l_xml_response := apex_web_service.make_request ( p_url => l_url, p_version => l_version, p_action => 'runReport', p_envelope => l_envelope, p_username => g_username, p_password => g_password );
    L_XML_RESPONSE := APEX_WEB_SERVICE.MAKE_REQUEST ( P_URL => L_URL, P_VERSION => L_VERSION, P_ACTION => 'runReport', P_ENVELOPE => L_ENVELOPE
 -- ,P_CREDENTIAL_STATIC_ID => 'GPMS_DEV'
    );
    WIP_DEBUG ( 3, 6001, 'Web Service Response ', L_XML_RESPONSE.GETCLOBVAL () );
    L_CLOB_REPORT_RESPONSE := APEX_WEB_SERVICE.PARSE_XML_CLOB ( P_XML => L_XML_RESPONSE, P_XPATH => ' //runReportResponse/runReportReturn/reportBytes', P_NS => ' xmlns="http://xmlns.oracle.com/oxp/service/PublicReportService"' );
    L_CLOB_TEMP := SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1, INSTR( SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1 ), '</ns2:report' ) - 1 );
    L_CLOB_REPORT_RESPONSE := L_CLOB_TEMP;
    L_CLOB_REPORT_DECODE := BASE64_DECODE_CLOB (L_CLOB_REPORT_RESPONSE);
    COMMIT;
    INSERT INTO XXGPMS_USER_ROLES (
      USER_LOGIN,
      USER_ID,
      ROLE_NAME,
      FIRST_NAME,
      LAST_NAME,
      LOCATION_CODE,
      LOCATION_NAME,
      TOWN,
      COUNTRY,
      DEPARTMENT,
      USERNAME,
      ACTIVE_FLAG
    )
      SELECT
        USER_LOGIN,
        USER_ID,
        ROLE_NAME,
        FIRST_NAME,
        LAST_NAME,
        LOCATION_CODE,
        LOCATION_NAME,
        TOWN,
        COUNTRY,
        DEPARTMENT,
        USERNAME,
        ACTIVE_FLAG
      FROM
        XMLTABLE( '/DATA_DS/G_USER_ROLES' PASSING XMLTYPE (L_CLOB_REPORT_DECODE) COLUMNS USER_LOGIN PATH 'USER_LOGIN',
        USER_ID PATH 'USER_ID',
        ROLE_NAME PATH 'ROLE_NAME',
 -- CREATION_DATE PATH 'CREATION_DATE',
        FIRST_NAME PATH 'FIRST_NAME',
        LAST_NAME PATH 'LAST_NAME',
        LOCATION_CODE PATH 'LOCATION_CODE',
        LOCATION_NAME PATH 'LOCATION_NAME',
        TOWN PATH 'TOWN',
        COUNTRY PATH 'COUNTRY',
        DEPARTMENT PATH 'DEPARTMENT',
        USERNAME PATH 'USERNAME',
        ACTIVE_FLAG PATH 'ACTIVE_FLAG' )                    XT;
    DBMS_LOB.FREETEMPORARY (L_CLOB_REPORT_RESPONSE);
    DBMS_LOB.FREETEMPORARY (L_CLOB_REPORT_DECODE);
    DBMS_LOB.FREETEMPORARY (L_CLOB_TEMP);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_RESPONSE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_DECODE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_TEMP, TRUE);
  END; --
  PROCEDURE GET_USERS IS
    L_URL                  VARCHAR2(4000) := P_URL;
    L_VERSION              VARCHAR2(1000) := '1.2';
    L_ENVELOPE             VARCHAR2(10000);
    L_XML_RESPONSE         XMLTYPE;
    L_CLOB_REPORT_RESPONSE CLOB;
    L_CLOB_REPORT_DECODE   CLOB;
    L_CLOB_TEMP            CLOB;
    L_OTBI_FLAG            VARCHAR2(1) := 'N';
  BEGIN
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_RESPONSE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_DECODE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_TEMP, TRUE);
    L_ENVELOPE := '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">
			<soap:Header/>
			   <soap:Body>
				  <pub:runReport>
					 <pub:reportRequest>
					   <pub:attributeFormat>xml</pub:attributeFormat>
						<pub:reportAbsolutePath>/Custom/Projects/Project Billing/Project Costs Report.xdo</pub:reportAbsolutePath>
					   <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
					 </pub:reportRequest>
					 <pub:appParams></pub:appParams>
				  </pub:runReport>
			   </soap:Body>
			</soap:Envelope>';
    WIP_DEBUG (3, 6000, 'Users Envelope ', L_ENVELOPE);
 -- l_xml_response := apex_web_service.make_request ( p_url => l_url, p_version => l_version, p_action => 'runReport', p_envelope => l_envelope, p_username => g_username, p_password => g_password );
    L_XML_RESPONSE := APEX_WEB_SERVICE.MAKE_REQUEST ( P_URL => L_URL, P_VERSION => L_VERSION, P_ACTION => 'runReport', P_ENVELOPE => L_ENVELOPE
 -- ,P_CREDENTIAL_STATIC_ID => 'GPMS_DEV'
    );
    WIP_DEBUG ( 3, 6001, 'Web Service Response ', L_XML_RESPONSE.GETCLOBVAL () );
    L_CLOB_REPORT_RESPONSE := APEX_WEB_SERVICE.PARSE_XML_CLOB ( P_XML => L_XML_RESPONSE, P_XPATH => ' //runReportResponse/runReportReturn/reportBytes', P_NS => ' xmlns="http://xmlns.oracle.com/oxp/service/PublicReportService"' );
    L_CLOB_TEMP := SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1, INSTR( SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1 ), '</ns2:report' ) - 1 );
    L_CLOB_REPORT_RESPONSE := L_CLOB_TEMP;
    L_CLOB_REPORT_DECODE := BASE64_DECODE_CLOB (L_CLOB_REPORT_RESPONSE);
    COMMIT;
    INSERT INTO XXGPMS_USERS (
      USER_ID,
      BUSINESS_GROUP_ID,
      ACTIVE_FLAG,
      USER_GUID,
      USERNAME,
      MULTITENANCY_USERNAME,
      PERSON_ID,
      PARTY_ID,
      OBJECT_VERSION_NUMBER
    )
      SELECT
        USER_ID,
        BUSINESS_GROUP_ID,
        ACTIVE_FLAG,
        USER_GUID,
        USERNAME,
        MULTITENANCY_USERNAME,
        PERSON_ID,
        PARTY_ID,
        OBJECT_VERSION_NUMBER
      FROM
        XMLTABLE( '/DATA_DS/G_USERS' PASSING XMLTYPE (L_CLOB_REPORT_DECODE) COLUMNS USER_ID PATH 'USER_ID',
        BUSINESS_GROUP_ID PATH 'BUSINESS_GROUP_ID',
        ACTIVE_FLAG PATH 'ACTIVE_FLAG',
        USER_GUID PATH 'USER_GUID',
        USERNAME PATH 'USERNAME',
        MULTITENANCY_USERNAME PATH 'MULTITENANCY_USERNAME',
        PERSON_ID PATH 'PERSON_ID',
        PARTY_ID PATH 'PARTY_ID',
        OBJECT_VERSION_NUMBER PATH 'OBJECT_VERSION_NUMBER' )                    XT;
    DBMS_LOB.FREETEMPORARY (L_CLOB_REPORT_RESPONSE);
    DBMS_LOB.FREETEMPORARY (L_CLOB_REPORT_DECODE);
    DBMS_LOB.FREETEMPORARY (L_CLOB_TEMP);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_RESPONSE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_DECODE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_TEMP, TRUE);
  END;
  PROCEDURE UPDATE_INVOICE_HEADER_DFFS(
    P_CONTRACT_ID IN NUMBER,
    P_JOB_ID IN NUMBER,
    P_ATTR1 IN NUMBER DEFAULT 0,
    P_RESPONSE_CODE OUT NUMBER
  ) IS
    L_URL                        VARCHAR2(4000);
    L_VERSION                    VARCHAR2(10) := 1.2;
    L_RESPONSE_CLOB              CLOB;
    L_ENVELOPE                   VARCHAR2(32000);
    P_EXP_AMT                    NUMBER;
    P_INTERNAL_COMMENT           VARCHAR2(1000);
    P_NARRATIVE_BILLING_OVERFLOW VARCHAR2(1000);
    P_EVENT_ATTR                 VARCHAR2(50);
    P_STANDARD_BILL_RATE_ATTR    NUMBER;
    P_PROJECT_BILL_RATE_ATTR     NUMBER;
    P_REALIZED_BILL_RATE_ATTR    NUMBER;
    P_BILLABLE_FLAG              VARCHAR2(10);
    P_EXPENDITURE_ITEM_ID        NUMBER;
    V_STATUSCODE                 NUMBER;
    V_VALUE                      NUMBER;
    L_XML_RESPONSE               XMLTYPE;
    L_CLOB_REPORT_RESPONSE       CLOB;
    L_CLOB_REPORT_DECODE         CLOB;
    L_CLOB_TEMP                  CLOB;
    V_ATTR1                      VARCHAR2(1000);
    V_ATTR2                      VARCHAR2(1000);
    L_STANDARD_RATE              NUMBER;
    L_AGREEMENT_RATE             NUMBER;
    V_INVOICE_ID                 NUMBER;
    L_ATTR1                      NUMBER;
    L_ATTR2                      NUMBER;
    L_ATTR3                      NUMBER;
    L_ATTR4                      NUMBER;
    L_ATTR5                      NUMBER;
    L_ATTR6                      NUMBER;
  BEGIN
    WIP_DEBUG ( 3, 12000, 'Update Invoice Header DFFs
      Contract ID : '
                          || P_CONTRACT_ID, ' JOB ID '
                                            || P_JOB_ID );
    L_VERSION := '1.2';
    IF P_URL IS NULL THEN
      P_URL := INSTANCE_URL
               || '/xmlpserver/services/ExternalReportWSSService';
    END IF;
    L_URL := P_URL;
 -- Call to the OTBI to fetch the projects rates
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_RESPONSE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_DECODE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_TEMP, TRUE);
    L_ENVELOPE := q'#<?xml version="1.0" encoding="UTF-8"?>#';
    L_ENVELOPE := '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">
						<soap:Header/>
			   <soap:Body>
				  <pub:runReport>
					 <pub:reportRequest>
					   <pub:attributeFormat>xml</pub:attributeFormat>
						 <pub:parameterNameValues>
							<pub:item>
								<pub:name>P_CONTRACT_ID</pub:name>
								<pub:values>
									<pub:item>'
                  || P_CONTRACT_ID
                  || '</pub:item>
								</pub:values>
							</pub:item>
              <pub:item>
								<pub:name>P_JOB_ID</pub:name>
								<pub:values>
									<pub:item>'
                  || P_JOB_ID
                  || '</pub:item>
								</pub:values>
							</pub:item>
						</pub:parameterNameValues>
					   <pub:reportAbsolutePath>/Custom/Projects/Project Billing/Project Costs Report.xdo</pub:reportAbsolutePath>
					   <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
					 </pub:reportRequest>
					 <pub:appParams></pub:appParams>
				  </pub:runReport>
			   </soap:Body>
			</soap:Envelope>';
    WIP_DEBUG (3, 120001, 'Envelope ', L_ENVELOPE);
    WIP_DEBUG (3, 120002, 'URL ', L_URL);
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Authorization';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'Bearer '
                                                    || V ('G_SAAS_ACCESS_TOKEN');
 -- APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'Bearer eyJ4NXQiOiJpeHZkTmRWSWJQdy1VVzUtdFhybS1lTE1GWFEiLCJraWQiOiJ0cnVzdHNlcnZpY2UiLCJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJBTVkuTUFSTElOIiwiaXNzIjoid3d3Lm9yYWNsZS5jb20iLCJleHAiOjE2ODg2NTQwMjQsInBybiI6IkFNWS5NQVJMSU4iLCJpYXQiOjE2ODg2Mzk2MjR9.XbZJNiWIf9GJXFlYF7P59BPV7O45pk9UlCEgfKGEgXGrLFTN2qC9IGYF9I35rsDLJ0HzJHu77IcmrSerSAYzfwPLor2GBDtIXyiKrVa45bZaTZ_YM6OLeD8Ic_axuZkuwDLcpASXNGNkJOHGG8gVBg7E7FHeY8vcO_vW7b33UJsLtblKVfR8UkQTx9_pHyNY_2-iOw8gN8-OreT_JVhEU53kHaTyW0OVq_GAniyhLjhq59JYfcA08ZI0XHAu0T5BSP3gfa3QmUMqkigVUagUl2tyO7Nitqt43MPiZ8tFUJVbgFAWZYFvLksBnq9uWPWe7_Fs3sfbBvdivYBoemLF1w';
 -- l_xml_response := apex_web_service.make_request ( p_url => l_url, p_version => l_version, p_action => 'runReport', p_envelope => l_envelope, p_username => g_username, p_password => g_password );
    L_XML_RESPONSE := APEX_WEB_SERVICE.MAKE_REQUEST ( P_URL => L_URL, P_VERSION => L_VERSION, P_ACTION => 'runReport', P_ENVELOPE => L_ENVELOPE
 -- ,P_CREDENTIAL_STATIC_ID => 'GPMS_DEV'
    );
    WIP_DEBUG (3, 120003, 'Bearer Token ', 'Bearer '
                                           || V ('G_SAAS_ACCESS_TOKEN'));
    WIP_DEBUG ( 3, 120004, 'Web Service Response', L_XML_RESPONSE.GETCLOBVAL () );
    L_CLOB_REPORT_RESPONSE := APEX_WEB_SERVICE.PARSE_XML_CLOB ( P_XML => L_XML_RESPONSE, P_XPATH => ' //runReportResponse/runReportReturn/reportBytes', P_NS => ' xmlns="http://xmlns.oracle.com/oxp/service/PublicReportService"' );
    L_CLOB_TEMP := SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1, INSTR( SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1 ), '</ns2:report' ) - 1 );
    L_CLOB_REPORT_RESPONSE := L_CLOB_TEMP;
    L_CLOB_REPORT_DECODE := BASE64_DECODE_CLOB (L_CLOB_REPORT_RESPONSE);
    COMMIT;
 -- End
    WIP_DEBUG ( 3, 120005, 'Web Service Response Decoded', L_CLOB_REPORT_DECODE );
    BEGIN
      DELETE FROM XXGPMS_PROJECT_INVOICES
      WHERE
        SESSION_ID = V('APP_SESSION');
      COMMIT;
 -- SELECT
 --     INVOICE_ID
 -- INTO V_INVOICE_ID
 --   FROM
 --     XMLTABLE( '/DATA_DS/G_INVOICE_HEADERS' PASSING XMLTYPE (L_CLOB_REPORT_DECODE) COLUMNS INVOICE_ID PATH 'INVOICE_ID') XT;
 -- exception
 --   when others then
 --   V_INVOICE_ID := NULL;
      INSERT INTO XXGPMS_PROJECT_INVOICES(
        INVOICE_ID,
        CONTRACT_ID,
        INVOICE_CURRENCY_CODE,
        REQUEST_ID,
        CREATED_BY,
        CREATION_DATE,
        INVOICE_LINE_ID,
        INVOICE_CURR_BILLED_AMT,
        INVOICE_DATE,
        ORG_ID,
        SESSION_ID,
        WRITE_OFF_AMOUNT
      )
        SELECT
          INVOICE_ID,
          CONTRACT_ID,
          INVOICE_CURRENCY_CODE,
          REQUEST_ID,
          CREATED_BY,
          CREATION_DATE,
          INVOICE_LINE_ID,
          INVOICE_CURR_BILLED_AMT,
          INVOICE_DATE,
          ORG_ID,
          V('APP_SESSION'),
          WRITE_OFF_AMOUNT
        FROM
          XMLTABLE('/DATA_DS/G_INVOICE_HEADERS' PASSING XMLTYPE (L_CLOB_REPORT_DECODE) COLUMNS INVOICE_ID PATH 'INVOICE_ID',
          CONTRACT_ID PATH 'CONTRACT_ID',
          INVOICE_CURRENCY_CODE PATH 'INVOICE_CURRENCY_CODE',
          REQUEST_ID PATH 'REQUEST_ID',
          CREATED_BY PATH 'PC',
          CREATION_DATE PATH 'CREATION_DATE',
          INVOICE_LINE_ID PATH 'INVOICE_LINE_ID',
          INVOICE_CURR_BILLED_AMT PATH 'INVOICE_CURR_BILLED_AMT',
          INVOICE_DATE PATH 'INVOICE_DATE',
          ORG_ID PATH 'ORG_ID',
          WRITE_OFF_AMOUNT PATH 'WRITE_OFF_AMOUNT' )                    ;
    END;
    COMMIT;
    WIP_DEBUG ( 3, 120006, 'Response of Web service'
                           ||APEX_WEB_SERVICE.G_STATUS_CODE, '');
    BEGIN
      SELECT
        DISTINCT JOB_APPROVAL_ID INTO L_ATTR2
      FROM
        XXGPMS_PROJECT_COSTS
      WHERE
        1=1 --SESSION_ID   = V('APP_SESSION')
        AND PROJECT_ID IN (
          SELECT
            DISTINCT PROJECT_ID
          FROM
            XXGPMS_PROJECT_CONTRACT
          WHERE
            CONTRACT_ID = P_CONTRACT_ID
        )
        AND JOB_APPROVAL_ID IS NOT NULL;
    EXCEPTION
      WHEN OTHERS THEN
        L_ATTR2 := NULL;
    END;
    FOR I IN (
      SELECT
        *
      FROM
        XXGPMS_PROJECT_INVOICES
      WHERE
        SESSION_ID = V('APP_SESSION')
    ) LOOP
 -- PATCH THE DFF VALUES
 -- ATTRIBUTE 1 IS  TOTAL WRITE/UP DOWN AMOUNT
 -- select sum(INVOICE_CURR_BILLED_AMT)*-1
 -- into   L_ATTR1
 -- from   xxgpms_project_invoices
 -- where  1=1--session_id = v('APP_SESSION')
 -- and    contract_id = P_CONTRACT_ID;
 -- and    trunc(creation_date) = trunc(sysdate)
      L_ATTR1 := I.WRITE_OFF_AMOUNT;
 -- ATTRIBUTE 2 IS THE JOB APPROVAL ID
 -- for i in (select sum(BILL_TRNS_AMOUNT) amt ,wip_category
 --  from   XXGPMS_PROJECT_EVENTS
 --  where  session_id = v('APP_SESSION')
 --  group  by wip_category)
 -- loop
 --   if i.wip_category = 'Labor Fees'
 --   then
 --     l_attr3 := i.amt;
 --   elsif i.wip_category =  'Hard Costs'
 --   then
 --     l_attr4 := i.amt;
 --   elsif i.wip_category = 'Soft Costs'
 --   then
 --     l_attr5 := i.amt;
 --   elsif i.wip_category = 'Fees'
 --   then
 --     l_attr6 := i.amt;
 --   end if;
 -- end loop;
      WIP_DEBUG (3, 120007, I.INVOICE_ID
                            ||' '
                            ||L_ATTR1
                            ||' '
                            ||L_ATTR2
                            ||' '
                            ||L_ATTR3
                            ||' '
                            ||L_ATTR4
                            ||' '
                            ||L_ATTR5
                            ||' '
                            ||L_ATTR6, '');
      L_URL := INSTANCE_URL
               || '/fscmRestApi/resources/11.13.18.05/projectContractInvoices/'
               ||I.INVOICE_ID
               ||'/child/InvoiceHeaderDff/'
               ||I.INVOICE_ID;
      WIP_DEBUG (3, 120008, L_URL, '');
      L_ENVELOPE := '{"writeOffAmount" : "'
                    || NVL(L_ATTR1, 0)
                       || '",
      "jobApprovalLevel" : "'
                       || L_ATTR2
                       || '",
      "totalLaborAmount" : "'
                       || NVL(L_ATTR3, 0)
                          || '",
      "totalHardCostAmount" : "'
                          || NVL(L_ATTR4, 0)
                             || '",
      "totalSoftCostAmount" : "'
                             || NVL(L_ATTR5, 0)
                                || '",
      "totalFeesAmount" : "'
                                || NVL(L_ATTR6, 0)
                                   || '"
       }';
      WIP_DEBUG (3, 120009, L_ENVELOPE, '');
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/json';
      L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST (
        P_URL => L_URL,
        P_HTTP_METHOD => 'PATCH',
        P_SCHEME => 'OAUTH_CLIENT_CRED',
        P_BODY => L_ENVELOPE
      );
      WIP_DEBUG (3, 120010, L_RESPONSE_CLOB, '');
      WIP_DEBUG (3, 120011, APEX_WEB_SERVICE.G_STATUS_CODE, '');
    END LOOP;
  END; -- Submit the Invoice
  PROCEDURE SUBMIT_INVOICE IS
    L_URL                        VARCHAR2(4000) := P_URL;
    L_VERSION                    VARCHAR2(10) := 1.2;
    L_RESPONSE_CLOB              CLOB;
    L_ENVELOPE                   VARCHAR2(32000);
    P_EXP_AMT                    NUMBER;
    P_INTERNAL_COMMENT           VARCHAR2(1000);
    P_NARRATIVE_BILLING_OVERFLOW VARCHAR2(1000);
    P_EVENT_ATTR                 VARCHAR2(50);
    P_STANDARD_BILL_RATE_ATTR    NUMBER;
    P_PROJECT_BILL_RATE_ATTR     NUMBER;
    P_REALIZED_BILL_RATE_ATTR    NUMBER;
    P_BILLABLE_FLAG              VARCHAR2(10);
    P_EXPENDITURE_ITEM_ID        NUMBER;
    V_STATUSCODE                 NUMBER;
    V_VALUE                      NUMBER;
    L_XML_RESPONSE               XMLTYPE;
    L_CLOB_REPORT_RESPONSE       CLOB;
    L_CLOB_REPORT_DECODE         CLOB;
    L_CLOB_TEMP                  CLOB;
    V_ATTR1                      VARCHAR2(1000);
    V_ATTR2                      VARCHAR2(1000);
    L_STANDARD_RATE              NUMBER;
    L_AGREEMENT_RATE             NUMBER;
    V_INVOICE_ID                 NUMBER;
    L_ATTR1                      NUMBER;
    L_ATTR2                      NUMBER;
    L_ATTR3                      NUMBER;
    L_ATTR4                      NUMBER;
    L_ATTR5                      NUMBER;
    L_ATTR6                      NUMBER;
  BEGIN
    WIP_DEBUG ( 3, 13000, 'Submit the Invoice', '');
    L_VERSION := '1.2';
    FOR I IN (
      SELECT
        *
      FROM
        XXGPMS_PROJECT_INVOICES
      WHERE
        SESSION_ID = V('APP_SESSION')
    ) LOOP
      L_URL := INSTANCE_URL
               || '/fscmRestApi/resources/11.13.18.05/projectContractInvoices/'
               ||I.INVOICE_ID
               ||'/action/submitProjectContractInvoice';
      WIP_DEBUG (3, 13001, L_URL, 'Invoice '
                                  ||I.INVOICE_ID);
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/vnd.oracle.adf.action+json';
      L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST (
        P_URL => L_URL,
        P_HTTP_METHOD => 'POST',
        P_SCHEME => 'OAUTH_CLIENT_CRED'
      );
      WIP_DEBUG (3, 13002, L_RESPONSE_CLOB, '');
      WIP_DEBUG (3, 13003, APEX_WEB_SERVICE.G_STATUS_CODE, '');
    END LOOP;
  END; --
  PROCEDURE GET_INVOICE_HISTORY(
    P_CONTRACT_ID IN NUMBER
  ) IS
    L_URL                  VARCHAR2(4000) := P_URL;
    L_VERSION              VARCHAR2(10) := 1.2;
    L_RESPONSE_CLOB        CLOB;
    L_ENVELOPE             VARCHAR2(32000);
    L_CLOB_REPORT_RESPONSE CLOB;
    L_CLOB_REPORT_DECODE   CLOB;
    L_CLOB_TEMP            CLOB;
    L_XML_RESPONSE         XMLTYPE;
  BEGIN
    WIP_DEBUG ( 3, 15000, 'Get Invoice History Contract ID: '
                          || P_CONTRACT_ID, NULL);
    L_VERSION := '1.2';
    IF P_URL IS NULL THEN
      P_URL := INSTANCE_URL
               || '/xmlpserver/services/ExternalReportWSSService';
    END IF;
    L_URL := P_URL;
 -- Call to the OTBI to fetch the projects rates
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_RESPONSE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_DECODE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_TEMP, TRUE);
    L_ENVELOPE := q'#<?xml version="1.0" encoding="UTF-8"?>#';
    L_ENVELOPE := '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">
						<soap:Header/>
			   <soap:Body>
				  <pub:runReport>
					 <pub:reportRequest>
					   <pub:attributeFormat>xml</pub:attributeFormat>
						 <pub:parameterNameValues>
							<pub:item>
								<pub:name>P_CONTRACT_ID_2</pub:name>
								<pub:values>
									<pub:item>'
                  || P_CONTRACT_ID
                  || '</pub:item>
								</pub:values>
                                </pub:item>
						</pub:parameterNameValues>
					   <pub:reportAbsolutePath>/Custom/Projects/Project Billing/Project Costs Report.xdo</pub:reportAbsolutePath>
					   <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
					 </pub:reportRequest>
					 <pub:appParams></pub:appParams>
				  </pub:runReport>
			   </soap:Body>
			</soap:Envelope>';
    WIP_DEBUG (3, 150001, 'Envelope ', L_ENVELOPE);
    WIP_DEBUG (3, 150002, 'URL ', L_URL);
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Authorization';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'Bearer '
                                                    || V ('G_SAAS_ACCESS_TOKEN');
    L_XML_RESPONSE := APEX_WEB_SERVICE.MAKE_REQUEST ( P_URL => L_URL, P_VERSION => L_VERSION, P_ACTION => 'runReport', P_ENVELOPE => L_ENVELOPE );
    WIP_DEBUG (3, 150003, 'Bearer Token ', 'Bearer '
                                           || V ('G_SAAS_ACCESS_TOKEN'));
    WIP_DEBUG ( 3, 150004, 'Web Service Response', L_XML_RESPONSE.GETCLOBVAL () );
    L_CLOB_REPORT_RESPONSE := APEX_WEB_SERVICE.PARSE_XML_CLOB ( P_XML => L_XML_RESPONSE, P_XPATH => ' //runReportResponse/runReportReturn/reportBytes', P_NS => ' xmlns="http://xmlns.oracle.com/oxp/service/PublicReportService"' );
    L_CLOB_TEMP := SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1, INSTR( SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1 ), '</ns2:report' ) - 1 );
    L_CLOB_REPORT_RESPONSE := L_CLOB_TEMP;
    L_CLOB_REPORT_DECODE := BASE64_DECODE_CLOB (L_CLOB_REPORT_RESPONSE);
    COMMIT;
    WIP_DEBUG ( 3, 150005, 'Web Service Response Decoded', L_CLOB_REPORT_DECODE );
    BEGIN
      INSERT INTO XXGPMS_PROJECT_INVOICE_HISTORY(
        INVOICE_DATE,
        INVOICE_NUMBER,
        ADJUSTMENTS,
        INVOICE_AMOUNT,
        TAX,
        TOTAL_INVOICE_AMOUNT,
        OPEN_BALANCE,
        LAST_RECEIPT_DATE,
        SESSION_ID,
        CONTRACT_ID,
        INVOICE_ID
      )
        SELECT
          INVOICE_DATE,
          INVOICE_NUMBER,
          NVL(ADJUSTMENTS, 0),
          INVOICE_AMOUNT,
          TAX,
          TOTAL_INVOICE_AMOUNT,
          OPEN_BALANCE,
          LAST_RECEIPT_DATE,
          V('APP_SESSION'),
          P_CONTRACT_ID,
          INVOICE_ID
        FROM
          XMLTABLE('/DATA_DS/G_INVOICE_HISTORY' PASSING XMLTYPE (L_CLOB_REPORT_DECODE) COLUMNS
          INVOICE_DATE PATH 'TRX_DATE',
          INVOICE_NUMBER PATH 'TRX_NUMBER',
          ADJUSTMENTS PATH 'ADJUSTED_AMOUNT',
          INVOICE_AMOUNT PATH 'INVOICE_AMOUNT',
          TAX PATH 'TAX_AMOUNT',
          TOTAL_INVOICE_AMOUNT PATH 'TOTAL_INVOICE_AMOUNT',
          OPEN_BALANCE PATH 'AMOUNT_DUE_REMAINING',
          LAST_RECEIPT_DATE PATH 'LAST_RCPT_DATE',
          INVOICE_ID PATH 'PROJECT_INVOICE_ID' )                    ;
    END;
    COMMIT;
    WIP_DEBUG ( 3, 150006, 'Response of Web service'
                           ||APEX_WEB_SERVICE.G_STATUS_CODE, '');
  EXCEPTION
    WHEN OTHERS THEN
      WIP_DEBUG ( 3, 15555, DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                            ||' '
                            ||SQLERRM, '');
  END GET_INVOICE_HISTORY;
  --
   PROCEDURE GET_MATTER_CREDITS(
    P_CONTRACT_ID IN NUMBER
  ) IS
    L_URL                  VARCHAR2(4000) := P_URL;
    L_VERSION              VARCHAR2(10) := 1.2;
    L_RESPONSE_CLOB        CLOB;
    L_ENVELOPE             VARCHAR2(32000);
    L_CLOB_REPORT_RESPONSE CLOB;
    L_CLOB_REPORT_DECODE   CLOB;
    L_CLOB_TEMP            CLOB;
    L_XML_RESPONSE         XMLTYPE;
  BEGIN
    WIP_DEBUG ( 3, 19000, 'Get Matter Credits Contract ID: '
                          || P_CONTRACT_ID, NULL);
    L_VERSION := '1.2';
    IF P_URL IS NULL THEN
      P_URL := INSTANCE_URL
               || '/xmlpserver/services/ExternalReportWSSService';
    END IF;
    L_URL := P_URL;
 -- Call to the OTBI to fetch the projects rates
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_RESPONSE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_DECODE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_TEMP, TRUE);
    L_ENVELOPE := q'#<?xml version="1.0" encoding="UTF-8"?>#';
    L_ENVELOPE := '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">
						<soap:Header/>
			   <soap:Body>
				  <pub:runReport>
					 <pub:reportRequest>
					   <pub:attributeFormat>xml</pub:attributeFormat>
						 <pub:parameterNameValues>
							<pub:item>
								<pub:name>P_CONTRACT_ID</pub:name>
								<pub:values>
									<pub:item>'
                  || P_CONTRACT_ID
                  || '</pub:item>
								</pub:values>
                                </pub:item>
						</pub:parameterNameValues>
					   <pub:reportAbsolutePath>/Custom/Projects/Project Billing/Project Costs Report.xdo</pub:reportAbsolutePath>
					   <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
					 </pub:reportRequest>
					 <pub:appParams></pub:appParams>
				  </pub:runReport>
			   </soap:Body>
			</soap:Envelope>';
    WIP_DEBUG (3, 19001, 'Envelope ', L_ENVELOPE);
    WIP_DEBUG (3, 19002, 'URL ', L_URL);
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Authorization';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'Bearer '
                                                    || V ('G_SAAS_ACCESS_TOKEN');
    L_XML_RESPONSE := APEX_WEB_SERVICE.MAKE_REQUEST ( P_URL => L_URL, P_VERSION => L_VERSION, P_ACTION => 'runReport', P_ENVELOPE => L_ENVELOPE );
    WIP_DEBUG (3, 19003, 'Bearer Token ', 'Bearer '
                                           || V ('G_SAAS_ACCESS_TOKEN'));
    WIP_DEBUG ( 3, 19004, 'Web Service Response', L_XML_RESPONSE.GETCLOBVAL () );
    L_CLOB_REPORT_RESPONSE := APEX_WEB_SERVICE.PARSE_XML_CLOB ( P_XML => L_XML_RESPONSE, P_XPATH => ' //runReportResponse/runReportReturn/reportBytes', P_NS => ' xmlns="http://xmlns.oracle.com/oxp/service/PublicReportService"' );
    L_CLOB_TEMP := SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1, INSTR( SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1 ), '</ns2:report' ) - 1 );
    L_CLOB_REPORT_RESPONSE := L_CLOB_TEMP;
    L_CLOB_REPORT_DECODE := BASE64_DECODE_CLOB (L_CLOB_REPORT_RESPONSE);
    COMMIT;
    WIP_DEBUG ( 3, 19005, 'Web Service Response Decoded', L_CLOB_REPORT_DECODE );
    BEGIN
      INSERT INTO XXGPMS_MATTER_CREDITS(
        MATTER_NUMBER,
        INVOICE_CURRENCY_CODE,
        CREDIT_TYPE,
        BILLED,
        PAID,
        APPLIED,
        AVAILABLE,
        SESSION_ID
      )
        SELECT
          PROJECT_NUMBER,
          INVOICE_CURRENCY_CODE,
          EXPENDITURE_TYPE_NAME,
          BILLED_AMOUNT,
          PAID_AMOUNT,
          APPLIED_AMOUNT,
          AVAILABLE_AMOUNT,
          V('APP_SESSION')
        FROM
          XMLTABLE('/DATA_DS/G_MATTER_CREDITS' PASSING XMLTYPE (L_CLOB_REPORT_DECODE) COLUMNS
          PROJECT_NUMBER PATH 'PROJECT_NUMBER',
          INVOICE_CURRENCY_CODE PATH 'INVOICE_CURRENCY_CODE',
          EXPENDITURE_TYPE_NAME PATH 'EXPENDITURE_TYPE_NAME',
          BILLED_AMOUNT PATH 'BILLED_AMOUNT',
          PAID_AMOUNT PATH 'PAID_AMOUNT',
          APPLIED_AMOUNT PATH 'APPLIED_AMOUNT',
          AVAILABLE_AMOUNT PATH 'AVAILABLE_AMOUNT')                    ;
    END;
    COMMIT;
    WIP_DEBUG ( 3, 19006, 'Response of Web service '
                           ||APEX_WEB_SERVICE.G_STATUS_CODE, '');
  EXCEPTION
    WHEN OTHERS THEN
      WIP_DEBUG ( 3, 19099, DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                            ||' '
                            ||SQLERRM, '');
  END GET_MATTER_CREDITS;
  --
  PROCEDURE GET_INTERPROJECTS(
    P_CONTRACT_ID IN NUMBER
  ) IS
    L_URL                  VARCHAR2(4000) := P_URL;
    L_VERSION              VARCHAR2(10) := 1.2;
    L_RESPONSE_CLOB        CLOB;
    L_ENVELOPE             VARCHAR2(32000);
    L_CLOB_REPORT_RESPONSE CLOB;
    L_CLOB_REPORT_DECODE   CLOB;
    L_CLOB_TEMP            CLOB;
    L_XML_RESPONSE         XMLTYPE;
  BEGIN
    WIP_DEBUG ( 3, 21000, 'Get Inter Projects Contract ID: '
                          || P_CONTRACT_ID, NULL);
    L_VERSION := '1.2';
    IF P_URL IS NULL THEN
      P_URL := INSTANCE_URL
               || '/xmlpserver/services/ExternalReportWSSService';
    END IF;
    L_URL := P_URL;
 -- Call to the OTBI to fetch the projects rates
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_RESPONSE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_DECODE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_TEMP, TRUE);
    L_ENVELOPE := q'#<?xml version="1.0" encoding="UTF-8"?>#';
    L_ENVELOPE := '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">
						<soap:Header/>
			   <soap:Body>
				  <pub:runReport>
					 <pub:reportRequest>
					   <pub:attributeFormat>xml</pub:attributeFormat>
						 <pub:parameterNameValues>
							<pub:item>
								<pub:name>P_CONTRACT_ID</pub:name>
								<pub:values>
									<pub:item>'
                  || P_CONTRACT_ID
                  || '</pub:item>
								</pub:values>
                                </pub:item>
						</pub:parameterNameValues>
					   <pub:reportAbsolutePath>/Custom/Projects/Project Billing/Project Costs Report.xdo</pub:reportAbsolutePath>
					   <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
					 </pub:reportRequest>
					 <pub:appParams></pub:appParams>
				  </pub:runReport>
			   </soap:Body>
			</soap:Envelope>';
    WIP_DEBUG (3, 21001, 'Envelope ', L_ENVELOPE);
    WIP_DEBUG (3, 21002, 'URL ', L_URL);
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Authorization';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'Bearer '
                                                    || V ('G_SAAS_ACCESS_TOKEN');
    L_XML_RESPONSE := APEX_WEB_SERVICE.MAKE_REQUEST ( P_URL => L_URL, P_VERSION => L_VERSION, P_ACTION => 'runReport', P_ENVELOPE => L_ENVELOPE );
    WIP_DEBUG (3, 21003, 'Bearer Token ', 'Bearer '
                                           || V ('G_SAAS_ACCESS_TOKEN'));
    WIP_DEBUG ( 3, 21004, 'Web Service Response', L_XML_RESPONSE.GETCLOBVAL () );
    L_CLOB_REPORT_RESPONSE := APEX_WEB_SERVICE.PARSE_XML_CLOB ( P_XML => L_XML_RESPONSE, P_XPATH => ' //runReportResponse/runReportReturn/reportBytes', P_NS => ' xmlns="http://xmlns.oracle.com/oxp/service/PublicReportService"' );
    L_CLOB_TEMP := SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1, INSTR( SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1 ), '</ns2:report' ) - 1 );
    L_CLOB_REPORT_RESPONSE := L_CLOB_TEMP;
    L_CLOB_REPORT_DECODE := BASE64_DECODE_CLOB (L_CLOB_REPORT_RESPONSE);
    COMMIT;
    WIP_DEBUG ( 3, 21005, 'Web Service Response Decoded', L_CLOB_REPORT_DECODE );
    BEGIN
      INSERT INTO XXGPMS_INTERPROJECTS(
        PROJECT_NUMBER,
        LABOR_WIP,
        FEES_WIP,
        HARD_WIP,
        SOFT_WIP,
        SESSION_ID
      )
        SELECT
          PROJECT_NUMBER,
          LABOR_WIP,
          FEES_WIP,
          HARD_WIP,
          SOFT_WIP,
          V('APP_SESSION')
        FROM
          XMLTABLE('/DATA_DS/G_INTERPROJECT' PASSING XMLTYPE (L_CLOB_REPORT_DECODE) COLUMNS
          PROJECT_NUMBER PATH 'PROJECT_NUMBER',
          LABOR_WIP PATH 'LABOR_WIP',
          FEES_WIP PATH 'FEES_WIP',
          HARD_WIP PATH 'HARD_WIP',
          SOFT_WIP PATH 'SOFT_WIP')                    ;
    END;
    COMMIT;
    WIP_DEBUG ( 3, 21006, 'Response of Web service '
                           ||APEX_WEB_SERVICE.G_STATUS_CODE, '');
  EXCEPTION
    WHEN OTHERS THEN
      WIP_DEBUG ( 3, 21099, DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                            ||' '
                            ||SQLERRM, '');
  END GET_INTERPROJECTS;
  --
  PROCEDURE GET_ALL_MATTERS
  IS
    L_RESPONSE_CLOB             CLOB;
    L_URL                       VARCHAR2(4000) := P_URL;
    L_CLOB_REPORT_RESPONSE       CLOB;
    L_CLOB_REPORT_DECODE         CLOB;
    L_CLOB_TEMP                  CLOB;
    L_VERSION                    VARCHAR2(10) := 1.2;
    L_ENVELOPE                   VARCHAR2(32000);
    L_XML_RESPONSE               XMLTYPE;
    V_STATUSCODE                 NUMBER;
    V_LAST_LOAD_TS               TIMESTAMP;
  BEGIN
    WIP_DEBUG(3,160000,'Get All Matters and Tasks','');
    L_VERSION := '1.2';
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_RESPONSE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_DECODE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_TEMP, TRUE);
    UPDATE XXGPMS_JOB_LOGS
    SET    START_TS = SYSTIMESTAMP
    WHERE  JOB_NAME = 'LOAD_PROJECTS';
    --
    BEGIN
      SELECT END_TS
      INTO   V_LAST_LOAD_TS
      FROM   XXGPMS_JOB_LOGS
      WHERE  JOB_NAME = 'LOAD_PROJECTS'
      ORDER  BY END_TS DESC
      FETCH FIRST ROW ONLY;
    EXCEPTION
      WHEN OTHERS THEN
        V_LAST_LOAD_TS := NULL;
    END;
    L_ENVELOPE := '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">
			<soap:Header/>
			   <soap:Body>
				  <pub:runReport>
					 <pub:reportRequest>
					   <pub:attributeFormat>xml</pub:attributeFormat>
                       <pub:parameterNameValues>
							<pub:item>
								<pub:name>P_PROJECT_CREATION_DATE</pub:name>
								<pub:values>
									<pub:item>'
                                    || NVL(V_LAST_LOAD_TS,'01-01-1001')
                                    || '</pub:item>
								</pub:values>
							</pub:item>
                       </pub:parameterNameValues>
					   <pub:reportAbsolutePath>/Custom/Projects/Project Billing/Project Costs Report.xdo</pub:reportAbsolutePath>
					   <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
					 </pub:reportRequest>
					 <pub:appParams></pub:appParams>
				  </pub:runReport>
			   </soap:Body>
			</soap:Envelope>';
    --
    WIP_DEBUG (3, 160001, 'Get Matters and Tasks Envelope ', L_ENVELOPE);
    WIP_DEBUG (3, 160002, L_URL, '');
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Authorization';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'Bearer '
                                                    || V ('G_SAAS_ACCESS_TOKEN');
    WIP_DEBUG ( 3, 160003, 'Get Matters and Tasks Bearer Token ', 'Bearer '
                                                         || V ('G_SAAS_ACCESS_TOKEN') );
    IF L_URL IS NULL THEN
      L_URL := INSTANCE_URL
               || '/xmlpserver/services/ExternalReportWSSService';
    END IF;
    L_XML_RESPONSE := APEX_WEB_SERVICE.MAKE_REQUEST ( P_URL => L_URL
          , P_VERSION => L_VERSION, P_ACTION => 'runReport'
          , P_ENVELOPE => L_ENVELOPE
    );
    V_STATUSCODE := APEX_WEB_SERVICE.G_STATUS_CODE;
    WIP_DEBUG (3, 160004, 'Response',L_XML_RESPONSE.GETCLOBVAL());
    WIP_DEBUG (3, 160005, 'Status Code: '||V_STATUSCODE,'');
    L_CLOB_REPORT_RESPONSE := APEX_WEB_SERVICE.PARSE_XML_CLOB ( P_XML => L_XML_RESPONSE, P_XPATH => ' //runReportResponse/runReportReturn/reportBytes', P_NS => ' xmlns="http://xmlns.oracle.com/oxp/service/PublicReportService"' );
    L_CLOB_TEMP := SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1, INSTR( SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1 ), '</ns2:report' ) - 1 );
    L_CLOB_REPORT_RESPONSE := L_CLOB_TEMP;
    L_CLOB_REPORT_DECODE := BASE64_DECODE_CLOB (L_CLOB_REPORT_RESPONSE);
    COMMIT;
    WIP_DEBUG (3, 160005,'CLOB Response', L_CLOB_REPORT_DECODE);
    IF APEX_WEB_SERVICE.G_STATUS_CODE IN (200, 201) THEN
      MERGE INTO XXGPMS_PROJECTS D USING(
              select PROJECT_NUMBER,
             TASK_ID,
             V('APP_SESSION')
           from
        XMLTABLE( '/DATA_DS/G_ALL_PROJECTS' PASSING XMLTYPE (L_CLOB_REPORT_DECODE)
          COLUMNS PROJECT_NUMBER PATH 'PROJECT_NUMBER',
                  TASK_ID PATH 'TASK_NUMBER')) XT
      ON (D.PROJECT_NUMBER = XT.PROJECT_NUMBER AND D.TASK_ID = XT.TASK_ID)
      WHEN NOT MATCHED THEN INSERT (D.PROJECT_NUMBER,D.TASK_ID)
      VALUES (XT.PROJECT_NUMBER,XT.TASK_ID);
    --   insert into xxgpms_projects (project_number
    --   ,task_id
    --   ,session_id
    --   )
    --   select PROJECT_NUMBER,
    --          TASK_ID,
    --          V('APP_SESSION')
    --   from
    --     XMLTABLE( '/DATA_DS/G_ALL_PROJECTS' PASSING XMLTYPE (L_CLOB_REPORT_DECODE)
    --       COLUMNS PROJECT_NUMBER PATH 'PROJECT_NUMBER',
    --               TASK_ID PATH 'TASK_NUMBER') XT;
    -- insert into XXGPMS_JOB_LOGS(JOB_NAME,END_TS,STATUS) values ('LOAD_PROJECTS',SYSTIMESTAMP,'A');
    update xxgpms_job_logs
    set    end_ts = systimestamp
    where  job_name = 'LOAD_PROJECTS';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
    WIP_DEBUG (3, 161000, DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, '');
  END;
  ---
  PROCEDURE GET_ALL_EXP_TYPES
  IS
    L_RESPONSE_CLOB             CLOB;
    L_URL                       VARCHAR2(4000) := P_URL;
    L_CLOB_REPORT_RESPONSE       CLOB;
    L_CLOB_REPORT_DECODE         CLOB;
    L_CLOB_TEMP                  CLOB;
    L_VERSION                    VARCHAR2(10) := 1.2;
    L_ENVELOPE                   VARCHAR2(32000);
    L_XML_RESPONSE               XMLTYPE;
    V_STATUSCODE                 NUMBER;
  BEGIN
    WIP_DEBUG(3,20000,'Get All Exp Types','');
    L_VERSION := '1.2';
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_RESPONSE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_REPORT_DECODE, TRUE);
    DBMS_LOB.CREATETEMPORARY (L_CLOB_TEMP, TRUE);
    --
    L_ENVELOPE := '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">
			<soap:Header/>
			   <soap:Body>
				  <pub:runReport>
					 <pub:reportRequest>
					   <pub:attributeFormat>xml</pub:attributeFormat>
					   <pub:reportAbsolutePath>/Custom/Projects/Project Billing/Project Costs Report.xdo</pub:reportAbsolutePath>
					   <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
					 </pub:reportRequest>
					 <pub:appParams></pub:appParams>
				  </pub:runReport>
			   </soap:Body>
			</soap:Envelope>';
    --
    WIP_DEBUG (3, 20001, 'Get Exp Types Envelope ', L_ENVELOPE);
    WIP_DEBUG (3, 20002, L_URL, '');
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Authorization';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'Bearer '
                                                    || V ('G_SAAS_ACCESS_TOKEN');
    WIP_DEBUG ( 3, 20003, 'Get Exp types Bearer Token ', 'Bearer '
                                                         || V ('G_SAAS_ACCESS_TOKEN') );
    IF L_URL IS NULL THEN
      L_URL := INSTANCE_URL
               || '/xmlpserver/services/ExternalReportWSSService';
    END IF;
    L_XML_RESPONSE := APEX_WEB_SERVICE.MAKE_REQUEST ( P_URL => L_URL
          , P_VERSION => L_VERSION, P_ACTION => 'runReport'
          , P_ENVELOPE => L_ENVELOPE
    );
    V_STATUSCODE := APEX_WEB_SERVICE.G_STATUS_CODE;
    WIP_DEBUG (3, 20004, 'Response',L_XML_RESPONSE.GETCLOBVAL());
    WIP_DEBUG (3, 20005, 'Status Code: '||V_STATUSCODE,'');
    L_CLOB_REPORT_RESPONSE := APEX_WEB_SERVICE.PARSE_XML_CLOB ( P_XML => L_XML_RESPONSE, P_XPATH => ' //runReportResponse/runReportReturn/reportBytes', P_NS => ' xmlns="http://xmlns.oracle.com/oxp/service/PublicReportService"' );
    L_CLOB_TEMP := SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1, INSTR( SUBSTR( L_CLOB_REPORT_RESPONSE, INSTR(L_CLOB_REPORT_RESPONSE, '>') + 1 ), '</ns2:report' ) - 1 );
    L_CLOB_REPORT_RESPONSE := L_CLOB_TEMP;
    L_CLOB_REPORT_DECODE := BASE64_DECODE_CLOB (L_CLOB_REPORT_RESPONSE);
    COMMIT;
    WIP_DEBUG (3, 20006,'CLOB Response', L_CLOB_REPORT_DECODE);
    IF APEX_WEB_SERVICE.G_STATUS_CODE IN (200, 201) THEN
      insert into xxgpms_exp_types (EXPENDITURE_TYPE_NAME
      ,EXPENDITURE_TYPE_ID
      ,session_id
      )
      select EXPENDITURE_TYPE_NAME,
             EXPENDITURE_TYPE_ID,
             V('APP_SESSION')
      from
        XMLTABLE( '/DATA_DS/G_EXP_TYPES' PASSING XMLTYPE (L_CLOB_REPORT_DECODE)
          COLUMNS EXPENDITURE_TYPE_NAME PATH 'EXPENDITURE_TYPE_NAME',
                  EXPENDITURE_TYPE_ID PATH 'EXPENDITURE_TYPE_ID') XT;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
    WIP_DEBUG (3, 21000, DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, '');
  END;
  ---
  PROCEDURE PERFORM_UNPROCESSED_COSTS_CALL(P_EXPENDITURE_ITEM_ID VARCHAR2,
                                 P_REVERSAL IN VARCHAR2 DEFAULT NULL,
                                 P_INTERNAL_COMMENT VARCHAR2,
                                 P_NARRATIVE_BILLING_OVERFLOW IN VARCHAR2 DEFAULT NULL,
                                 P_EVENT_ATTR IN VARCHAR2 DEFAULT NULL,
                                 P_STANDARD_BILL_RATE_ATTR IN NUMBER DEFAULT NULL,
                                 P_PROJECT_BILL_RATE_ATTR IN NUMBER DEFAULT NULL,
                                 P_REALIZED_BILL_RATE_ATTR IN NUMBER DEFAULT NULL,
                                 P_HOURS_ENTERED IN NUMBER DEFAULT NULL,
                                 P_RESPONSE OUT VARCHAR2,
                                 P_RESPONSE_CODE OUT NUMBER)
  IS
    V_EXP_COSTS_ROW XXGPMS_PROJECT_COSTS%ROWTYPE;
    L_URL                     VARCHAR2(4000);
    L_ENVELOPE                VARCHAR2(32000);
    L_RESPONSE_CLOB           CLOB;
    V_EXPENDITURE_BATCH       VARCHAR2(100);
    V_STATUS                  VARCHAR2(100);
    V_ORIGINAL_QUANTITY       NUMBER;
    V_BUSINESS_UNIT           VARCHAR2(100);
    V_BUSINESS_UNIT_ID        NUMBER;
  BEGIN
  SELECT
      BU_NAME,
      BUSINESS_UNIT_ID
      INTO V_BUSINESS_UNIT,
           V_BUSINESS_UNIT_ID
    FROM
      XXGPMS_PROJECT_CONTRACT
    WHERE
      ROWNUM = 1
      AND SESSION_ID = V ('APP_SESSION')
      AND PROJECT_NUMBER = PROJECT_NUMBER;
    FOR I IN (SELECT COLUMN_VALUE EXP_ID FROM TABLE(SELECT APEX_STRING.SPLIT(
              trim(both '-' from P_EXPENDITURE_ITEM_ID),'-') FROM DUAL)
              )
    LOOP
        WIP_DEBUG ( 2, 14105, 'Expenditure Item ID '|| I.EXP_ID, '' );
      SELECT
        V ('APP_SESSION'),
        TRANSACTION_SOURCE,
        DOCUMENT_NAME,
        DOC_ENTRY_NAME,
        'Pending',
        CASE WHEN P_REVERSAL = 'Y'
        THEN - 1 * QUANTITY
        ELSE P_HOURS_ENTERED
        END ,
        QUANTITY,
        UNIT_OF_MEASURE,
        PERSON_NAME,
        TASK_NUMBER,
        PROJECT_NUMBER,
        EXPENDITURE_TYPE_NAME,
        ORIG_TRANSACTION_REFERENCE,
        EXPENDITURE_ITEM_DATE,
        TRANSACTION_SOURCE_ID,
        DOCUMENT_ID,
        EXP_ORG_ID,
        EXPENDITURE_COMMENT,
        REALIZED_BILL_RATE_ATTR,
        PROJECT_BILL_RATE_ATTR,
        STANDARD_BILL_RATE_ATTR
        INTO V_EXPENDITURE_BATCH,
             V_EXP_COSTS_ROW.TRANSACTION_SOURCE,
             V_EXP_COSTS_ROW.DOCUMENT_NAME,
             V_EXP_COSTS_ROW.DOC_ENTRY_NAME,
             V_STATUS,
             V_EXP_COSTS_ROW.QUANTITY,
             V_ORIGINAL_QUANTITY,
             V_EXP_COSTS_ROW.UNIT_OF_MEASURE,
             V_EXP_COSTS_ROW.PERSON_NAME,
             V_EXP_COSTS_ROW.TASK_NUMBER,
             V_EXP_COSTS_ROW.PROJECT_NUMBER,
             V_EXP_COSTS_ROW.EXPENDITURE_TYPE_NAME,
             V_EXP_COSTS_ROW.ORIG_TRANSACTION_REFERENCE,
             V_EXP_COSTS_ROW.EXPENDITURE_ITEM_DATE,
             V_EXP_COSTS_ROW.TRANSACTION_SOURCE_ID,
             V_EXP_COSTS_ROW.DOCUMENT_ID,
             V_EXP_COSTS_ROW.EXP_ORG_ID,
             V_EXP_COSTS_ROW.EXPENDITURE_COMMENT,
             V_EXP_COSTS_ROW.REALIZED_BILL_RATE_ATTR,
             V_EXP_COSTS_ROW.PROJECT_BILL_RATE_ATTR,
             V_EXP_COSTS_ROW.STANDARD_BILL_RATE_ATTR
      FROM
        XXGPMS_PROJECT_COSTS
      WHERE
        SESSION_ID = V ('APP_SESSION')
        AND EXPENDITURE_ITEM_ID = I.EXP_ID;
      L_URL := INSTANCE_URL
               || '/fscmRestApi/resources/11.13.18.05/unprocessedProjectCosts';
      L_ENVELOPE := '{"ExpenditureBatch" : "'
                    || V_EXPENDITURE_BATCH
                    || '",
                              "TransactionSource" : "'
                    || V_EXP_COSTS_ROW.TRANSACTION_SOURCE
                    || '",
                              "BusinessUnit" : "'
                    || V_BUSINESS_UNIT
                    || '",
                              "Document" : "'
                    || V_EXP_COSTS_ROW.DOCUMENT_NAME
                    || '",
                              "DocumentEntry" : "'
                    || V_EXP_COSTS_ROW.DOC_ENTRY_NAME
                    || '",
                              "Status" : "'
                    || V_STATUS
                    || '",
                              "Quantity" : "'
                    || V_EXP_COSTS_ROW.QUANTITY
                    || '",
                              "UnitOfMeasureCode" : "'
                    || V_EXP_COSTS_ROW.UNIT_OF_MEASURE
                    || '",
                              "PersonName" : "'
                    || V_EXP_COSTS_ROW.PERSON_NAME
                    || '",
                              "ReversedOriginalTransactionReference" : "'
                    || CASE WHEN P_REVERSAL = 'Y' THEN V_EXP_COSTS_ROW.ORIG_TRANSACTION_REFERENCE ELSE NULL END
                    || '",
                              "OriginalTransactionReference" : "'
                    || CASE WHEN P_REVERSAL = 'Y' THEN regexp_replace(V_EXP_COSTS_ROW.ORIG_TRANSACTION_REFERENCE,'*-[0-9]*','-'||XXGPMS_TRANS_SEQ.NEXTVAL)
                    ELSE  'WIP-'||XXGPMS_TRANS_SEQ.NEXTVAL
                    END
                    || '",'||CASE WHEN P_REVERSAL = 'Y' THEN '
                         "UnmatchedNegativeTransactionFlag" : "false",' END
                         ||'
                          "Comment" : "'
                    || V_EXP_COSTS_ROW.EXPENDITURE_COMMENT
                    || '",
                              "ProjectStandardCostCollectionFlexfields" : ['
                    || '{
                                                                                  "_EXPENDITURE_ITEM_DATE" : "'
                    || TO_CHAR(V_EXP_COSTS_ROW.EXPENDITURE_ITEM_DATE, 'YYYY-MM-DD')
                       || '",
                               "_ORGANIZATION_ID" : "'
                        || V_EXP_COSTS_ROW.EXP_ORG_ID
                         || '",
                                                                                  "_PROJECT_ID_Display" : "'
                       || V_EXP_COSTS_ROW.PROJECT_NUMBER
                       || '",
                                                                                  "_TASK_ID_Display" : "'
                       || V_EXP_COSTS_ROW.TASK_NUMBER
                       || '",
                                                                                  "_EXPENDITURE_TYPE_ID_Display" : "'
                       || V_EXP_COSTS_ROW.EXPENDITURE_TYPE_NAME
                       || '"}],
                        "UnprocessedCostRestDFF":['
                       ||'{"internalComment" : "'
                             || P_INTERNAL_COMMENT
                             || '",
                               "narrativeBillingOverflow1" : "'
                             || P_NARRATIVE_BILLING_OVERFLOW
                             || '" ,
                               "event" : "'
                             || P_EVENT_ATTR
                             || '" ,
                               "standardBillRate" : "'
                             || TRIM(V_EXP_COSTS_ROW.STANDARD_BILL_RATE_ATTR)
                             || '",
                               "projectBillRate" : "'
                             || TRIM(V_EXP_COSTS_ROW.PROJECT_BILL_RATE_ATTR)
                             || '",
                               "realizedBillRate" : "'
                             || TRIM(NVL(P_REALIZED_BILL_RATE_ATTR,V_EXP_COSTS_ROW.REALIZED_BILL_RATE_ATTR))
                             || '"}]}';
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/json';
      WIP_DEBUG (2, 14150, L_URL, '');
      WIP_DEBUG (2, 14200, L_ENVELOPE, '');
      L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST (
        P_URL => L_URL,
        P_HTTP_METHOD => 'POST',
        P_SCHEME => 'OAUTH_CLIENT_CRED',
        P_BODY => L_ENVELOPE
      );
      P_RESPONSE_CODE := APEX_WEB_SERVICE.G_STATUS_CODE;
      P_RESPONSE := L_RESPONSE_CLOB;
      WIP_DEBUG (2, 14250, '', L_RESPONSE_CLOB);
      WIP_DEBUG (3, 14260, APEX_WEB_SERVICE.G_STATUS_CODE, '');
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      WIP_DEBUG(3,14300,SQLERRM,'');
  END;
  ---
  PROCEDURE PERFORM_SPLIT_TRANSFER(P_EXPENDITURE_ITEM_ID VARCHAR2
                                   ,P_JUSTIFICATION VARCHAR2
                                   ,P_RESPONSE OUT VARCHAR2
                                   ,P_RESPONSE_CODE OUT NUMBER
                                   ,P_SOURCE_PROJECT VARCHAR2 DEFAULT NULL,
                                   P_ACTION VARCHAR2
                                   ,P_TOTAL_HOURS NUMBER)
  IS
    L_RESPONSE_CLOB             CLOB;
    L_URL                       VARCHAR2(4000) := P_URL;
    L_CLOB_REPORT_RESPONSE       CLOB;
    L_CLOB_REPORT_DECODE         CLOB;
    L_CLOB_TEMP                  CLOB;
    L_VERSION                    VARCHAR2(10) := 1.2;
    L_ENVELOPE                   VARCHAR2(32000);
    L_XML_RESPONSE               XMLTYPE;
    V_STATUSCODE                 NUMBER;
    V_FINAL_RESPONSE             CLOB;
    V_DERIVED_QUANTITY           NUMBER;
    V_TASK_NUMBER                NUMBER;
    V_BILLABLE_FLAG              VARCHAR2(100);
  BEGIN
    WIP_DEBUG (2, 170000,'', P_EXPENDITURE_ITEM_ID);
    IF (P_ACTION IN ('S','T'))
    THEN
      FOR I IN (SELECT COLUMN_VALUE EXP_ID FROM TABLE(SELECT APEX_STRING.SPLIT(P_EXPENDITURE_ITEM_ID,'-') FROM DUAL)
             )
      LOOP
        L_URL := INSTANCE_URL
               || '/fscmRestApi/resources/11.13.18.05/projectCosts/'
               || I.EXP_ID
               || '/action/adjustProjectCosts';
        WIP_DEBUG (2, 170001, '', L_URL);
        FOR SPLITS IN (SELECT * from xxgpms_project_split
                   where session_id = v('APP_SESSION')
                   AND   ACTION <> 'MULTI_SPLIT_TRANS'
            )
        LOOP
          IF SPLITS.ACTION = 'SPLIT' AND SPLITS.TASK_NUMBER IS NULL
          THEN
            SELECT TASK_NUMBER
            INTO   V_TASK_NUMBER
            FROM   XXGPMS_PROJECT_COSTS
            WHERE  EXPENDITURE_ITEM_ID = I.EXP_ID
            AND    SESSION_ID = V('APP_SESSION');
           END IF;
           IF SPLITS.QUANTITY IS NULL AND SPLITS.PERCENTAGE IS NOT NULL
           THEN
               -- CONVERT PERCENTAGE TO QUANTITY
             BEGIN
               SELECT QUANTITY * (SPLITS.PERCENTAGE/100)
               INTO   V_DERIVED_QUANTITY
               FROM   XXGPMS_PROJECT_COSTS
               WHERE  EXPENDITURE_ITEM_ID = I.EXP_ID
               AND    SESSION_ID = V('APP_SESSION');
             EXCEPTION
               WHEN OTHERS THEN
                 V_DERIVED_QUANTITY := NULL;
             END;
           END IF;
           BEGIN
             SELECT CASE BILLABLE_FLAG WHEN 'Y' THEN 'Set to Billable'
                                       WHEN 'N' THEN 'Set to nonbillable'
                    END
             INTO   V_BILLABLE_FLAG
             FROM   XXGPMS_PROJECT_COSTS
             WHERE  SESSION_ID = V('APP_SESSION')
             AND    EXPENDITURE_ITEM_ID = I.EXP_ID;
           EXCEPTION
             WHEN OTHERS THEN
               NULL;
           END;
           L_ENVELOPE := q'#{
                          "AdjustmentTypeCode": "#'||SPLITS.ACTION||q'#",
                          "ProjectNumber": "#'||SPLITS.PROJECT_NUMBER||q'#",
                          "TaskNumber": "#'||NVL(SPLITS.TASK_NUMBER,V_TASK_NUMBER)||q'#",
                          "Justification": "#'||P_JUSTIFICATION||q'#",
                          "Quantity" : "#'||NVL(SPLITS.QUANTITY,V_DERIVED_QUANTITY)||q'#",
                          "AdjustmentType" : "#'||V_BILLABLE_FLAG||q'#"
                          }#';
           WIP_DEBUG (2, 170002, '', L_ENVELOPE);
           APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
           APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/vnd.oracle.adf.action+json';
           L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST ( P_URL => L_URL
                , P_HTTP_METHOD => 'POST'
                , P_BODY => L_ENVELOPE
                , P_SCHEME => 'OAUTH_CLIENT_CRED');
           APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE ();
           WIP_DEBUG (2, 170003, '', L_RESPONSE_CLOB);
           P_RESPONSE_CODE := APEX_WEB_SERVICE.G_STATUS_CODE;
           IF APEX_WEB_SERVICE.G_STATUS_CODE NOT IN (200,201)
           THEN
             V_FINAL_RESPONSE := V_FINAL_RESPONSE||'</br> '||SPLITS.ACTION||' of Expenditure Item ID: '||I.EXP_ID||' to the project '||SPLITS.PROJECT_NUMBER
                                    ||' and task '||SPLITS.TASK_NUMBER||' failed due to the following reason: '||
                                    L_RESPONSE_CLOB;
             EXIT;
           ELSE
             V_STATUSCODE := UPDATE_PROJECT_LINES_DFF (I.EXP_ID,P_JUSTIFICATION);
             IF V_STATUSCODE IN (200,201)
             THEN
               V_FINAL_RESPONSE := V_FINAL_RESPONSE||'</br> '||SPLITS.ACTION||' of Expenditure Item ID: '||I.EXP_ID||' to the project '||SPLITS.PROJECT_NUMBER
                                      ||' and task '||SPLITS.TASK_NUMBER||' succeeded: '||
                                      L_RESPONSE_CLOB;
             END IF;
           END IF;
        END LOOP;
      END LOOP;
    ELSE
    --   FOR I IN (SELECT COLUMN_VALUE EXP_ID FROM TABLE(SELECT APEX_STRING.SPLIT(P_EXPENDITURE_ITEM_ID,'-') FROM DUAL)
            --  )
    --   LOOP
        V_FINAL_RESPONSE := V_FINAL_RESPONSE||' '||PROCESS_TRANSFER_SPLIT (P_EXPENDITURE_ITEM_LIST =>  P_EXPENDITURE_ITEM_ID,
                                                                           PROJECT_NUMBER    => P_SOURCE_PROJECT,
                                                                           P_JUSTIFICATION => P_JUSTIFICATION,
                                                                           P_TOTAL_HOURS => P_TOTAL_HOURS
                                                                          );
    --   END LOOP;
        -- P_RESPONSE := ltrim(V_FINAL_RESPONSE,'</br>');
         WIP_DEBUG (3, 170004,v_final_response,null);
        P_RESPONSE := V_FINAL_RESPONSE;
    END IF;
    EXCEPTION
    WHEN OTHERS THEN
          WIP_DEBUG (3, 171000,null,DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
  END;
---
  PROCEDURE PERFORM_ADJUST_PROJECT_COSTS(P_EXPENDITURE_ITEM_ID VARCHAR2,
                                 P_ADJUSTMENT_TYPE_CODE IN VARCHAR2,
                                 P_JUSTIFICATION IN VARCHAR2,
                                 P_EXPENDITURE_TYPE IN VARCHAR2 DEFAULT NULL,
                                 P_QUANTITY IN NUMBER DEFAULT NULL,
                                 P_RESPONSE OUT VARCHAR2,
                                 P_RESPONSE_CODE OUT NUMBER)
  IS
    L_URL               VARCHAR2(1000);
    V_PROJECT_COSTS_ROW XXGPMS_PROJECT_COSTS%ROWTYPE;
    L_RESPONSE_CLOB     CLOB;
    L_ENVELOPE          VARCHAR2(32000);
  BEGIN
    WIP_DEBUG (2, 18000, P_EXPENDITURE_ITEM_ID, '');
    FOR I IN (SELECT COLUMN_VALUE EXP_ID FROM TABLE(
               SELECT APEX_STRING.SPLIT(TRIM(BOTH '-' FROM P_EXPENDITURE_ITEM_ID),'-') FROM DUAL)
             )
    LOOP
      L_URL := INSTANCE_URL
         || '/fscmRestApi/resources/11.13.18.05/projectCosts/'
         || I.EXP_ID
         || '/action/adjustProjectCosts';
      SELECT *
      INTO   V_PROJECT_COSTS_ROW
      FROM   XXGPMS_PROJECT_COSTS
      WHERE  SESSION_ID = V('APP_SESSION')
      AND    EXPENDITURE_ITEM_ID = I.EXP_ID;
      L_ENVELOPE := q'#{
                               "AdjustmentTypeCode": "#'||P_ADJUSTMENT_TYPE_CODE||q'#",
                               "ProjectNumber": "#'||V_PROJECT_COSTS_ROW.PROJECT_NUMBER||q'#",
                               "TaskNumber": "#'||V_PROJECT_COSTS_ROW.TASK_NUMBER||q'#",
                               "Justification": "#'||P_JUSTIFICATION||q'#",
                               "Quantity": "#'||NVL(P_QUANTITY,V_PROJECT_COSTS_ROW.QUANTITY)||q'#",
                               "ExpenditureType": "#'||P_EXPENDITURE_TYPE||q'#"
                               }#';
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
      APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/vnd.oracle.adf.action+json';
      WIP_DEBUG (2, 18001, '', L_URL);
      WIP_DEBUG (2, 18002, '', L_ENVELOPE);
      L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST ( P_URL => L_URL
           , P_HTTP_METHOD => 'POST'
           , P_BODY => L_ENVELOPE
           , P_SCHEME => 'OAUTH_CLIENT_CRED');
      APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE ();
      WIP_DEBUG (2, 18003, '', L_RESPONSE_CLOB);
      P_RESPONSE_CODE := APEX_WEB_SERVICE.G_STATUS_CODE;
      P_RESPONSE := L_RESPONSE_CLOB;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      WIP_DEBUG (2, 18099, '', SQLERRM);
  END;
---
  PROCEDURE PERFORM_SPLIT_TRANSFER_NEW(P_EXPENDITURE_ITEM_ID VARCHAR2
                                   ,P_JUSTIFICATION VARCHAR2
                                   ,P_RESPONSE OUT VARCHAR2
                                   ,P_RESPONSE_CODE OUT NUMBER
                                   ,P_SOURCE_PROJECT VARCHAR2 DEFAULT NULL
                                   ,P_ACTION VARCHAR2
                                   )
  IS
    L_RESPONSE_CLOB             CLOB;
    L_URL                       VARCHAR2(4000) := P_URL;
    L_CLOB_REPORT_RESPONSE       CLOB;
    L_CLOB_REPORT_DECODE         CLOB;
    L_CLOB_TEMP                  CLOB;
    L_VERSION                    VARCHAR2(10) := 1.2;
    L_ENVELOPE                   VARCHAR2(32000);
    L_XML_RESPONSE               XMLTYPE;
    V_STATUSCODE                 NUMBER;
    V_FINAL_RESPONSE             CLOB;
    V_DERIVED_QUANTITY           NUMBER;
  BEGIN
    WIP_DEBUG (2, 170000,'', P_EXPENDITURE_ITEM_ID);
    FOR I IN (SELECT COLUMN_VALUE EXP_ID FROM TABLE(SELECT APEX_STRING.SPLIT(P_EXPENDITURE_ITEM_ID,'-') FROM DUAL)
             )
    LOOP
      L_URL := INSTANCE_URL
               || '/fscmRestApi/resources/11.13.18.05/projectCosts/'
               || I.EXP_ID
               || '/action/adjustProjectCosts';
      WIP_DEBUG (2, 170001, '', L_URL);
    FOR SPLITS IN (SELECT * from xxgpms_project_split
            where session_id = v('APP_SESSION')
            )
    LOOP
      IF SPLITS.QUANTITY IS NULL AND SPLITS.PERCENTAGE IS NOT NULL
      THEN
        -- CONVERT PERCENTAGE TO QUANTITY
      BEGIN
        SELECT QUANTITY * (SPLITS.PERCENTAGE/100)
        INTO   V_DERIVED_QUANTITY
        FROM   XXGPMS_PROJECT_COSTS
        WHERE  EXPENDITURE_ITEM_ID = I.EXP_ID
        AND    SESSION_ID = V('APP_SESSION');
      EXCEPTION
        WHEN OTHERS THEN
          V_DERIVED_QUANTITY := NULL;
      END;
    END IF;
    IF SPLITS.ACTION <> 'MULTI_SPLIT_TRANS'
      THEN
        L_ENVELOPE := q'#{
                          "AdjustmentTypeCode": "#'||SPLITS.ACTION||q'#",
                          "ProjectNumber": "#'||SPLITS.PROJECT_NUMBER||q'#",
                          "TaskNumber": "#'||SPLITS.TASK_NUMBER||q'#",
                          "Justification": "#'||P_JUSTIFICATION||q'#",
                          "Quantity" : "#'||NVL(SPLITS.QUANTITY,V_DERIVED_QUANTITY)||q'#"
                          }#';
        WIP_DEBUG (2, 170002, '', L_ENVELOPE);
        APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).NAME := 'Content-Type';
        APEX_WEB_SERVICE.G_REQUEST_HEADERS (1).VALUE := 'application/vnd.oracle.adf.action+json';
        L_RESPONSE_CLOB := APEX_WEB_SERVICE.MAKE_REST_REQUEST ( P_URL => L_URL
             , P_HTTP_METHOD => 'POST'
             , P_BODY => L_ENVELOPE
             , P_SCHEME => 'OAUTH_CLIENT_CRED');
        APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE ();
        WIP_DEBUG (2, 170003, '', L_RESPONSE_CLOB);
        P_RESPONSE_CODE := APEX_WEB_SERVICE.G_STATUS_CODE;
        IF APEX_WEB_SERVICE.G_STATUS_CODE NOT IN (200,201)
        THEN
          V_FINAL_RESPONSE := V_FINAL_RESPONSE||'</br> '||SPLITS.ACTION||' of Expenditure Item ID: '||I.EXP_ID||' to the project '||SPLITS.PROJECT_NUMBER
                                 ||' and task '||SPLITS.TASK_NUMBER||' failed due to the following reason: '||
                                 L_RESPONSE_CLOB;
          EXIT;
        ELSE
          V_FINAL_RESPONSE := V_FINAL_RESPONSE||'</br> '||SPLITS.ACTION||' of Expenditure Item ID: '||I.EXP_ID||' to the project '||SPLITS.PROJECT_NUMBER
                                 ||' and task '||SPLITS.TASK_NUMBER||' succeeded: '||
                                 L_RESPONSE_CLOB;
        END IF;
    -- ELSE
    --     V_FINAL_RESPONSE := V_FINAL_RESPONSE||' '||PROCESS_TRANSFER_SPLIT (P_EXPENDITURE_ITEM_LIST =>  I.EXP_ID,
    --                                                                        PROJECT_NUMBER    => P_SOURCE_PROJECT,
    --                                                                        P_JUSTIFICATION => P_JUSTIFICATION
    --                                                                       );
    END IF;
  END LOOP;
      -- IF V_FINAL_RESPONSE <> '0'
      -- THEN
      --   EXIT;
      -- END IF;
    END LOOP;
    P_RESPONSE := ltrim(V_FINAL_RESPONSE,'</br>');
  EXCEPTION
    WHEN OTHERS THEN
          WIP_DEBUG (3, 171000,'',DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
  END;
BEGIN
 --   SELECT
 --     VALUE INTO G_PASSWORD1
 --   FROM
 --     GPMS_PROFILE_OPTIONS
 --   WHERE
 --     PROFILE_OPTION = 'CLOUD_PASSWORD';
 -- apex_credential.set_session_credentials (
 --   p_credential_static_id => 'GPMS_DEV',
 --   p_username => 'amy.marlin',
 --   p_password => g_password1
 -- );
 --   APEX_CREDENTIAL.SET_SESSION_TOKEN (
 --     P_CREDENTIAL_STATIC_ID => 'GPMS_DEV',
 --     P_TOKEN_TYPE => APEX_CREDENTIAL.C_TOKEN_ACCESS,
 --     P_TOKEN_VALUE => V ('G_SAAS_ACCESS_TOKEN'),
 --     P_TOKEN_EXPIRES => TRUNC(G_TOKEN_TS)
 --   );
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
        UPPER(ORGANIZATION_NAME) = V('P0_CLIENT')
    )
    AND UPPER(ENVIRONMENT_NAME) = V('P0_ENV');
  APEX_WEB_SERVICE.OAUTH_SET_TOKEN(
    P_TOKEN =>V ('G_SAAS_ACCESS_TOKEN')
  );
 --  begin
 --     apex_credential.set_session_credentials (
 --     p_credential_static_id => 'GPMS_DEV',
 --     p_client_id => 'amy.marlin',
 --     p_client_secret => v('G_SAAS_ACCESS_TOKEN') );
 --  end;
EXCEPTION
  WHEN OTHERS THEN
    WIP_DEBUG(2,99999,'CLIENT: '|| V('P0_CLIENT')||' ENV : '||V('P0_ENV')||' ERROR: '||SQLERRM,'');
    RAISE;
END;
/