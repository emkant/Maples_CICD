  CREATE TABLE "XXGPMS_JOB_LOGS" 
   (	"JOB_NAME" VARCHAR2(100 CHAR),
	"START_TS" TIMESTAMP (6) WITH LOCAL TIME ZONE,
	"END_TS" TIMESTAMP (6) WITH LOCAL TIME ZONE,
	"STATUS" VARCHAR2(100 CHAR),
	"ERROR" CLOB
   ) SEGMENT CREATION DEFERRED
  PCTFREE 10 PCTUSED 40 INITRANS 10 NOCOMPRESS LOGGING
  TABLESPACE "DATA"
 LOB ("ERROR") STORE AS SECUREFILE  (
  TABLESPACE "DATA" ENABLE STORAGE IN ROW CHUNK 8192
  NOCACHE LOGGING NOCOMPRESS KEEP_DUPLICATES )