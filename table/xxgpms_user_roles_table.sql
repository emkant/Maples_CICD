  CREATE TABLE "XXGPMS_USER_ROLES" 
   (	"ID" NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY
 MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER NOCYCLE NOT NULL ENABLE,
	"USER_LOGIN" VARCHAR2(4000),
	"USER_ID" NUMBER,
	"ROLE_NAME" VARCHAR2(1000),
	"CREATION_DATE" DATE,
	"FIRST_NAME" VARCHAR2(1000),
	"LAST_NAME" VARCHAR2(1000),
	"LOCATION_CODE" VARCHAR2(1000),
	"LOCATION_NAME" VARCHAR2(1000),
	"TOWN" VARCHAR2(2000),
	"COUNTRY" VARCHAR2(1000),
	"DEPARTMENT" VARCHAR2(2000),
	"USERNAME" VARCHAR2(2000),
	"ACTIVE_FLAG" VARCHAR2(100),
	CONSTRAINT "XXGPMS_USER_ROLES_ID_PK" PRIMARY KEY ("ID")
  USING INDEX
  PCTFREE 10 INITRANS 20 MAXTRANS 255 LOGGING
  TABLESPACE "DATA"  ENABLE
   ) SEGMENT CREATION DEFERRED
  PCTFREE 10 PCTUSED 40 INITRANS 10 NOCOMPRESS LOGGING
  TABLESPACE "DATA"