  CREATE TABLE "XXGPMS_PROJECT_CONTRACT" 
   (	"PROJECT_ID" NUMBER(18,0) NOT NULL ENABLE,
	"PROJECT_NUMBER" VARCHAR2(25),
	"CONTRACT_NUMBER" VARCHAR2(100),
	"BU_NAME" VARCHAR2(50),
	"CURRENCY_CODE" VARCHAR2(50),
	"CONTRACT_TYPE_NAME" VARCHAR2(100),
	"SESSION_ID" NUMBER,
	"ORGANIZATION_NAME" VARCHAR2(100),
	"PROJECT_NAME" VARCHAR2(100),
	"LEGAL_ENTITY_NAME" VARCHAR2(150),
	"CONTRACT_ID" NUMBER,
	"CUSTOMER_NAME" VARCHAR2(1000),
	"RETAINER_BALANCE" NUMBER,
	"BUSINESS_UNIT_ID" NUMBER,
	"USER_TRANSACTION_SOURCE" VARCHAR2(100),
	"TRANSACTION_SOURCE_ID" NUMBER,
	"TRUST_BALANCE" NUMBER,
	"CREATION_DATE" DATE,
	"CREATED_BY" VARCHAR2(100),
	"LAST_UPDATE_DATE" DATE,
	"LAST_UPDATED_BY" VARCHAR2(100),
	"CONTRACT_TYPE_ID" NUMBER,
	"EBILL_MATTER_ID" VARCHAR2(100),
	"TAX_REGISTRATION_TYPE" VARCHAR2(100),
	"TAX_REGISTRATION_NUMBER" VARCHAR2(100),
	"TAX_REGISTRATION_COUNTRY" VARCHAR2(500),
	"CONTRACT_OFFICE" VARCHAR2(200),
	"BILL_CUSTOMER_NAME" VARCHAR2(1000),
	"BILL_CUSTOMER_ACCT" VARCHAR2(1000),
	"BILL_CUSTOMER_SITE" VARCHAR2(1000),
	"CLIENT_NUMBER" VARCHAR2(1000)
   ) SEGMENT CREATION DEFERRED
  PCTFREE 10 PCTUSED 40 INITRANS 10 NOCOMPRESS LOGGING
  TABLESPACE "DATA"