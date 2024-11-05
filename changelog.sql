-- Create Database Lock Table
CREATE TABLE MAPLESDEV.DATABASECHANGELOGLOCK (ID INTEGER NOT NULL, LOCKED NUMBER(1) NOT NULL, LOCKGRANTED TIMESTAMP, LOCKEDBY VARCHAR2(255), CONSTRAINT PK_DATABASECHANGELOGLOCK PRIMARY KEY (ID));

-- Initialize Database Lock Table
DELETE FROM MAPLESDEV.DATABASECHANGELOGLOCK;

INSERT INTO MAPLESDEV.DATABASECHANGELOGLOCK (ID, LOCKED) VALUES (1, 0);

-- Lock Database
UPDATE MAPLESDEV.DATABASECHANGELOGLOCK SET LOCKED = 1, LOCKEDBY = 'Vamsis-MacBook-Pro.local (2406:b400:d5:c081:99c0:6bfd:949b:221d%en0)', LOCKGRANTED = SYSTIMESTAMP WHERE ID = 1 AND LOCKED = 0;

-- Create Database Change Log Table
CREATE TABLE MAPLESDEV.DATABASECHANGELOG (ID VARCHAR2(255) NOT NULL, AUTHOR VARCHAR2(255) NOT NULL, FILENAME VARCHAR2(255) NOT NULL, DATEEXECUTED TIMESTAMP NOT NULL, ORDEREXECUTED INTEGER NOT NULL, EXECTYPE VARCHAR2(10) NOT NULL, MD5SUM VARCHAR2(35), DESCRIPTION VARCHAR2(255), COMMENTS VARCHAR2(255), TAG VARCHAR2(255), LIQUIBASE VARCHAR2(20), CONTEXTS VARCHAR2(255), LABELS VARCHAR2(255), DEPLOYMENT_ID VARCHAR2(10));

-- *********************************************************************
-- Update Database Script
-- *********************************************************************
-- Change Log: changelog.xml
-- Ran at: 05/11/24, 5:05 pm
-- Against: MAPLESDEV@jdbc:oracle:thin:@(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=adb.us-ashburn-1.oraclecloud.com))(connect_data=(service_name=g15d023dedae272_fronteragpmsdev_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))
-- Liquibase version: 4.25.0
-- *********************************************************************

-- Changeset changelog.xml::1730806245648-1::vamsikrishna (generated)
CREATE TABLE MAPLESDEV.NEW_TABLE (ID VARCHAR2(130 CHAR));

INSERT INTO MAPLESDEV.DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE, DEPLOYMENT_ID) VALUES ('1730806245648-1', 'vamsikrishna (generated)', 'changelog.xml', SYSTIMESTAMP, 1, '9:c48d096e4649fcced946c6a32b38cd2d', 'createTable tableName=NEW_TABLE', '', 'EXECUTED', NULL, NULL, '4.25.0', '0806535584');

-- Changeset changelog.xml::1730806245648-2::vamsikrishna (generated)
CREATE TABLE MAPLESDEV.NEW_TABLE_GEN (ID NUMBER);

INSERT INTO MAPLESDEV.DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE, DEPLOYMENT_ID) VALUES ('1730806245648-2', 'vamsikrishna (generated)', 'changelog.xml', SYSTIMESTAMP, 2, '9:24f87b46c51c2ddb01cbb51240636b5b', 'createTable tableName=NEW_TABLE_GEN', '', 'EXECUTED', NULL, NULL, '4.25.0', '0806535584');

-- Changeset changelog.xml::1730806245648-3::vamsikrishna (generated)
CREATE TABLE MAPLESDEV.TEST (ID NUMBER GENERATED BY DEFAULT ON NULL AS IDENTITY NOT NULL, CONSTRAINT TEST_PK PRIMARY KEY (ID));

INSERT INTO MAPLESDEV.DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE, DEPLOYMENT_ID) VALUES ('1730806245648-3', 'vamsikrishna (generated)', 'changelog.xml', SYSTIMESTAMP, 3, '9:cb2cac5c3f4b34b6d25a1639abfcb250', 'createTable tableName=TEST', '', 'EXECUTED', NULL, NULL, '4.25.0', '0806535584');

-- Changeset changelog.xml::1730806245648-4::vamsikrishna (generated)
DROP VIEW MAPLESDEV.DATABASECHANGELOG_DETAILS;

INSERT INTO MAPLESDEV.DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE, DEPLOYMENT_ID) VALUES ('1730806245648-4', 'vamsikrishna (generated)', 'changelog.xml', SYSTIMESTAMP, 4, '9:6a6914b8b9b47bb95f18b5d4ba2a0042', 'dropView viewName=DATABASECHANGELOG_DETAILS', '', 'EXECUTED', NULL, NULL, '4.25.0', '0806535584');

-- Changeset changelog.xml::1730806245648-5::vamsikrishna (generated)
DROP TABLE MAPLESDEV.DATABASECHANGELOG_ACTIONS;

INSERT INTO MAPLESDEV.DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE, DEPLOYMENT_ID) VALUES ('1730806245648-5', 'vamsikrishna (generated)', 'changelog.xml', SYSTIMESTAMP, 5, '9:6262b91778a6047bcd754f2f40add19b', 'dropTable tableName=DATABASECHANGELOG_ACTIONS', '', 'EXECUTED', NULL, NULL, '4.25.0', '0806535584');

-- Changeset changelog.xml::1730806245648-6::vamsikrishna (generated)
DROP TABLE MAPLESDEV.NEW_TABLE_GEN2;

INSERT INTO MAPLESDEV.DATABASECHANGELOG (ID, AUTHOR, FILENAME, DATEEXECUTED, ORDEREXECUTED, MD5SUM, DESCRIPTION, COMMENTS, EXECTYPE, CONTEXTS, LABELS, LIQUIBASE, DEPLOYMENT_ID) VALUES ('1730806245648-6', 'vamsikrishna (generated)', 'changelog.xml', SYSTIMESTAMP, 6, '9:26f83639bd3cfc3d417b4e6947bb02b1', 'dropTable tableName=NEW_TABLE_GEN2', '', 'EXECUTED', NULL, NULL, '4.25.0', '0806535584');

-- Release Database Lock
UPDATE MAPLESDEV.DATABASECHANGELOGLOCK SET LOCKED = 0, LOCKEDBY = NULL, LOCKGRANTED = NULL WHERE ID = 1;

