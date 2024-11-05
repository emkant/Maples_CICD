  CREATE TABLE "PRT_ENVIRONMENTS_ERR$" 
   (	"ORA_ERR_NUMBER$" NUMBER,
	"ORA_ERR_MESG$" VARCHAR2(2000),
	"ORA_ERR_ROWID$" UROWID(4000),
	"ORA_ERR_OPTYP$" VARCHAR2(2),
	"ORA_ERR_TAG$" VARCHAR2(2000),
	"ENVIRONMENT_ID" VARCHAR2(4000),
	"ORGANIZATION_ID" VARCHAR2(4000),
	"ENVIRONMENT_NAME" VARCHAR2(32767),
	"BASE_URL" VARCHAR2(32767),
	"ENVIRONMENT_TYPE_CODE" VARCHAR2(32767),
	"ENVIRONMENT_PURPOSE_CODE" VARCHAR2(32767),
	"SSO_MODE_CODE" VARCHAR2(32767),
	"UPGRADE_SCHEDULE_CODE" VARCHAR2(32767),
	"UPGRADE_CONCURRENCY_CODE" VARCHAR2(32767),
	"VERSION" VARCHAR2(32767),
	"DESCRIPTION" VARCHAR2(32767),
	"ENABLED_FLAG" VARCHAR2(32767),
	"DFF_N1" VARCHAR2(4000),
	"DFF_N2" VARCHAR2(4000),
	"DFF_N3" VARCHAR2(4000),
	"DFF_N4" VARCHAR2(4000),
	"DFF_N5" VARCHAR2(4000),
	"DFF_V1" VARCHAR2(32767),
	"DFF_V2" VARCHAR2(32767),
	"DFF_V3" VARCHAR2(32767),
	"DFF_V4" VARCHAR2(32767),
	"DFF_V5" VARCHAR2(32767),
	"DFF_D1" VARCHAR2(4000),
	"DFF_D2" VARCHAR2(4000),
	"CREATION_DATE" VARCHAR2(4000),
	"CREATED_BY" VARCHAR2(32767),
	"LAST_UPDATE_DATE" VARCHAR2(4000),
	"LAST_UPDATED_BY" VARCHAR2(32767),
	"PROJECT_LABEL" VARCHAR2(32767),
	"TRUST_LABEL" VARCHAR2(32767),
	"RETAINER_LABEL" VARCHAR2(32767)
   ) SEGMENT CREATION DEFERRED
  PCTFREE 10 PCTUSED 40 INITRANS 10 NOCOMPRESS LOGGING
  TABLESPACE "DATA"