  CREATE TABLE "PRT_ENVIRONMENTS" 
   (	"ENVIRONMENT_ID" NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY
 MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER NOCYCLE NOT NULL ENABLE,
	"ORGANIZATION_ID" NUMBER NOT NULL ENABLE,
	"ENVIRONMENT_NAME" VARCHAR2(100) NOT NULL ENABLE,
	"BASE_URL" VARCHAR2(1000) NOT NULL ENABLE,
	"ENVIRONMENT_TYPE_CODE" VARCHAR2(100) NOT NULL ENABLE,
	"ENVIRONMENT_PURPOSE_CODE" VARCHAR2(100) NOT NULL ENABLE,
	"SSO_MODE_CODE" VARCHAR2(100) NOT NULL ENABLE,
	"UPGRADE_SCHEDULE_CODE" VARCHAR2(100),
	"UPGRADE_CONCURRENCY_CODE" VARCHAR2(100),
	"VERSION" VARCHAR2(100),
	"DESCRIPTION" VARCHAR2(1000),
	"ENABLED_FLAG" VARCHAR2(1) NOT NULL ENABLE,
	"DFF_N1" NUMBER,
	"DFF_N2" NUMBER,
	"DFF_N3" NUMBER,
	"DFF_N4" NUMBER,
	"DFF_N5" NUMBER,
	"DFF_V1" VARCHAR2(240),
	"DFF_V2" VARCHAR2(240),
	"DFF_V3" VARCHAR2(240),
	"DFF_V4" VARCHAR2(240),
	"DFF_V5" VARCHAR2(240),
	"DFF_D1" DATE,
	"DFF_D2" DATE,
	"CREATION_DATE" TIMESTAMP (6) WITH LOCAL TIME ZONE NOT NULL ENABLE,
	"CREATED_BY" VARCHAR2(100) NOT NULL ENABLE,
	"LAST_UPDATE_DATE" TIMESTAMP (6) WITH LOCAL TIME ZONE NOT NULL ENABLE,
	"LAST_UPDATED_BY" VARCHAR2(100) NOT NULL ENABLE,
	"PROJECT_LABEL" VARCHAR2(50),
	"TRUST_LABEL" VARCHAR2(50),
	"RETAINER_LABEL" VARCHAR2(100),
	CONSTRAINT "PRT_ENVIRONMENTS_PK" PRIMARY KEY ("ENVIRONMENT_ID")
  USING INDEX
  PCTFREE 10 INITRANS 20 MAXTRANS 255 LOGGING
  TABLESPACE "DATA"  ENABLE
   ) SEGMENT CREATION DEFERRED
  PCTFREE 10 PCTUSED 40 INITRANS 10 NOCOMPRESS LOGGING
  TABLESPACE "DATA"