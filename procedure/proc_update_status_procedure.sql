CREATE OR REPLACE EDITIONABLE PROCEDURE "PROC_UPDATE_STATUS" (p_project_number in varchar2) 
 IS 
  l_url varchar2(4000) ; 
  name varchar2(4000); 
  buffer varchar2(4000);  
  l_envelope varchar2(4000); 
  p_username varchar2(4000); 
  p_password varchar(4000); 
  l_response_xml        XMLTYPE; 
  l_response_clob  CLOB; 
  p_nic_number varchar2(100); 
  l_version varchar2(1000); 
  l_report_response varchar2(32000); 
  l_report_decode varchar2(32000); 
  l_temp varchar2(32000) ; 
   
 begin 
  
p_username := 'amy.marlin'; 
p_password := 'Arn36576'; 
--p_password := 'Fr0ntera!123'; 
l_version := '1.2'; 
--- Code for Project Costs 
--DELETE FROM XXGPMS_PROJECT_COSTS WHERE SESSION_ID = V('SESSION'); 
--DELETE FROM XXGPMS_PROJECT_EVENTS WHERE SESSION_ID = V('SESSION'); 
DELETE FROM XXGPMS_PROJECT_COSTS; 
DELETE FROM XXGPMS_PROJECT_EVENTS; 
DELETE FROM AXXML_TAB; 
 insert into axxml_tab (id, vc2_data) values (1, 'PROC_UPDATE_STATUS for '||p_project_number); 
--l_url := 'https://eda.fa.us1.oraclecloud.com/xmlpserver/services/ExternalReportWSSService'; 
l_url := 'https://adc3-zlnq-fa-ext.oracledemos.com/xmlpserver/services/ExternalReportWSSService'; 
  
 l_envelope := '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService"> 
   <soap:Header/> 
   <soap:Body> 
      <pub:runReport> 
         <pub:reportRequest> 
           <pub:attributeFormat>xml</pub:attributeFormat> 
             <pub:parameterNameValues> 
			    <pub:item> 
				    <pub:name>P_Proj_Number</pub:name> 
				    <pub:values> 
					    <pub:item>' || p_project_number || '</pub:item> 
				    </pub:values> 
			    </pub:item> 
            </pub:parameterNameValues>	 
           <pub:reportAbsolutePath>/Custom/Project Accounting/Project Costs Report.xdo</pub:reportAbsolutePath> 
           <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload> 
         </pub:reportRequest> 
         <pub:appParams></pub:appParams> 
      </pub:runReport> 
   </soap:Body> 
</soap:Envelope>'; 
  
  l_response_xml :=   apex_web_service.make_request( 
            p_url      => l_url, 
            p_version  => l_version, 
            p_action   => 'runReport', 
            p_envelope => l_envelope, 
            p_username => p_username, 
            p_password => p_password); 
  
 insert into axxml_tab (id, xml_data) values (2, l_response_xml); 
  
  
  l_report_response := apex_web_service.parse_xml( 
  
     p_xml => l_response_xml, 
     p_xpath => ' //runReportResponse/runReportReturn/reportBytes', 
     p_ns => ' xmlns="http://xmlns.oracle.com/oxp/service/PublicReportService"' ); 
  
  insert into axxml_tab (id, xml_data) values (3, l_report_response); 
  
  l_temp := substr(l_report_response, instr(l_report_response,'>') +1,instr(substr(l_report_response, instr(l_report_response,'>') +1),'</ns2:report')-1); 
  l_report_response := l_temp; 
   
--l_report_response := 'PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPCEtLUdlbmVyYXRlZCBieSBPcmFjbGUgQkkgUHVibGlzaGVyIC1EYXRhZW5naW5lLCBkYXRhbW9kZWw6X0N1c3RvbV9Qcm9jdXJlbWVudF9QdXJjaGFzaW5nX1N1cHBsaWVyU2FtcGxlX3hkbSAtLT4KPERBVEFfRFM+CjxHXzE+CjxTVVBQTElFUl9OVU1CRVI+MTI1MjwvU1VQUExJRVJfTlVNQkVSPjxTVVBQTElFUl9OQU1FPkxlZSBTdXBwbGllczwvU1VQUExJRVJfTkFNRT4KPC9HXzE+CjxHXzE+CjxTVVBQTElFUl9OVU1CRVI+MTI1MzwvU1VQUExJRVJfTlVNQkVSPjxTVVBQTElFUl9OQU1FPlN0YWZmaW5nIFNlcnZpY2VzPC9TVVBQTElFUl9OQU1FPgo8L0dfMT4KPC9EQVRBX0RTPg=='; 
  
  
 l_report_decode := utl_raw.cast_to_varchar2(utl_encode.base64_decode(utl_raw.cast_to_raw(l_report_response))); 
  
  insert into axxml_tab (id, xml_data) values (4, l_report_decode); 
  
  
 insert into XXGPMS_PROJECT_COSTS 
( 
PROJECT_ID 
,PROJECT_NUMBER  
,BILLABLE_FLAG 
,TASK_ID 
,TASK_NUMBER 
,PROJECT_STATUS_CODE 
,PROJECT_NAME 
,EXPENDITURE_ITEM_ID 
,EXPENDITURE_ITEM_DATE 
,REVENUE_RECOGNIZED_FLAG 
,BILL_HOLD_FLAG 
,QUANTITY 
,PROJFUNC_RAW_COST 
,RAW_COST_RATE 
,PROJFUNC_BURDENED_COST 
,BURDEN_COST_RATE 
,INVOICED_FLAG 
,REVENUE_HOLD_FLAG 
,ACCT_CURRENCY_CODE 
,ACCT_RAW_COST 
,ACCT_BURDENED_COST 
,TASK_BILLABLE_FLAG 
,EXTERNAL_BILL_RATE 
,TOTAL_AMOUNT 
,INTERNAL_COMMENT 
,NARRATIVE_BILLING_OVERFLOW 
,TASK_START_DATE 
,TASK_COMPLETION_DATE 
,PROJECT_START_DATE 
,TASK_NAME 
,EXPENDITURE_COMMENT 
,UNIT_OF_MEASURE 
,FIRST_NAME 
,LAST_NAME 
,PERSON_NAME 
,EXPENDITURE_TYPE_NAME 
,EXPENDITURE_CATEGORY_NAME 
,JOB_NAME 
,JOB_ID 
,SESSION_ID 
) 
SELECT  
PROJECT_ID 
,PROJECT_NUMBER  
,BILLABLE_FLAG 
,TASK_ID PATH 
,TASK_NUMBER PATH 
,PROJECT_STATUS_CODE 
,PROJECT_NAME 
,EXPENDITURE_ITEM_ID 
,EXPENDITURE_ITEM_DATE 
,REVENUE_RECOGNIZED_FLAG 
,BILL_HOLD_FLAG 
,QUANTITY 
,PROJFUNC_RAW_COST 
,RAW_COST_RATE 
,PROJFUNC_BURDENED_COST 
,BURDEN_COST_RATE 
,INVOICED_FLAG 
,REVENUE_HOLD_FLAG 
,ACCT_CURRENCY_CODE 
,ACCT_RAW_COST 
,ACCT_BURDENED_COST 
,TASK_BILLABLE_FLAG 
,EXTERNAL_BILL_RATE 
,ROUND(NVL(EXTERNAL_BILL_RATE,0) * QUANTITY,2) 
,INTERNAL_COMMENT 
,NARRATIVE_BILLING_OVERFLOW 
,TASK_START_DATE 
,TASK_COMPLETION_DATE 
,PROJECT_START_DATE 
,TASK_NAME 
,EXPENDITURE_COMMENT 
,UNIT_OF_MEASURE 
,FIRST_NAME 
,LAST_NAME 
,FIRST_NAME || ' ' || LAST_NAME 
,EXPENDITURE_TYPE_NAME 
,EXPENDITURE_CATEGORY_NAME 
,JOB_NAME 
,JOB_ID 
, V('APP_SESSION') 
FROM   
--       AXXML_TAB x,  
       XMLTABLE('/DATA_DS/G_PROJECT_COST' 
         PASSING XMLTYPE(l_report_decode) 
         COLUMNS  
               PROJECT_ID PATH 'PROJECT_ID', 
               PROJECT_NUMBER     PATH 'PROJECT_NUMBER', 
                BILLABLE_FLAG PATH 'BILLABLE_FLAG', 
                TASK_ID PATH 'TASK_ID', 
                TASK_NUMBER PATH 'TASK_NUMBER', 
                PROJECT_STATUS_CODE PATH 'PROJECT_STATUS_CODE', 
                PROJECT_NAME PATH 'PROJECT_NAME', 
                EXPENDITURE_ITEM_ID PATH 'EXPENDITURE_ITEM_ID', 
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
                JOB_NAME PATH 'JOB_NAME', 
                JOB_ID PATH 'JOB_ID' 
               ) xt; 
   
--- Code for Project Events 
--l_url := 'https://eda.fa.us1.oraclecloud.com/xmlpserver/services/ExternalReportWSSService'; 
l_url := 'https://adc3-zlnq-fa-ext.oracledemos.com/xmlpserver/services/ExternalReportWSSService'; 
  
 l_envelope := '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService"> 
   <soap:Header/> 
   <soap:Body> 
      <pub:runReport> 
         <pub:reportRequest> 
           <pub:attributeFormat>xml</pub:attributeFormat> 
             <pub:parameterNameValues> 
			    <pub:item> 
				    <pub:name>P_Proj_Number</pub:name> 
				    <pub:values> 
					    <pub:item>' || p_project_number || '</pub:item> 
				    </pub:values> 
			    </pub:item> 
            </pub:parameterNameValues>	 
           <pub:reportAbsolutePath>/Custom/Project Accounting/Project Events Report.xdo</pub:reportAbsolutePath> 
           <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload> 
         </pub:reportRequest> 
         <pub:appParams></pub:appParams> 
      </pub:runReport> 
   </soap:Body> 
</soap:Envelope>'; 
  
  l_response_xml :=   apex_web_service.make_request( 
            p_url      => l_url, 
            p_version  => l_version, 
            p_action   => 'runReport', 
            p_envelope => l_envelope, 
            p_username => p_username, 
            p_password => p_password); 
  
 insert into axxml_tab (id, xml_data) values (2, l_response_xml); 
  
  
  l_report_response := apex_web_service.parse_xml( 
  
     p_xml => l_response_xml, 
     p_xpath => ' //runReportResponse/runReportReturn/reportBytes', 
     p_ns => ' xmlns="http://xmlns.oracle.com/oxp/service/PublicReportService"' ); 
  
  insert into axxml_tab (id, xml_data) values (3, l_report_response); 
  
  l_temp := substr(l_report_response, instr(l_report_response,'>') +1,instr(substr(l_report_response, instr(l_report_response,'>') +1),'</ns2:report')-1); 
  l_report_response := l_temp; 
   
--l_report_response := 'PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPCEtLUdlbmVyYXRlZCBieSBPcmFjbGUgQkkgUHVibGlzaGVyIC1EYXRhZW5naW5lLCBkYXRhbW9kZWw6X0N1c3RvbV9Qcm9jdXJlbWVudF9QdXJjaGFzaW5nX1N1cHBsaWVyU2FtcGxlX3hkbSAtLT4KPERBVEFfRFM+CjxHXzE+CjxTVVBQTElFUl9OVU1CRVI+MTI1MjwvU1VQUExJRVJfTlVNQkVSPjxTVVBQTElFUl9OQU1FPkxlZSBTdXBwbGllczwvU1VQUExJRVJfTkFNRT4KPC9HXzE+CjxHXzE+CjxTVVBQTElFUl9OVU1CRVI+MTI1MzwvU1VQUExJRVJfTlVNQkVSPjxTVVBQTElFUl9OQU1FPlN0YWZmaW5nIFNlcnZpY2VzPC9TVVBQTElFUl9OQU1FPgo8L0dfMT4KPC9EQVRBX0RTPg=='; 
  
  
 l_report_decode := utl_raw.cast_to_varchar2(utl_encode.base64_decode(utl_raw.cast_to_raw(l_report_response))); 
  
  insert into axxml_tab (id, xml_data) values (5, l_report_decode); 
  
  
 insert into XXGPMS_PROJECT_EVENTS 
( 
     
    PROJECT_ID 
	,SEGMENT1 
	,PROJECT_STATUS_CODE 
	,PROJECT_NAME 
	,EVENT_ID 
	,EVENT_NUM 
	,EVENT_TYPE_CODE 
	,BILL_TRNS_AMOUNT 
	,BILL_TRNS_CURRENCY_CODE 
	,BILL_HOLD_FLAG 
	,REVENUE_HOLD_FLAG 
	,INVOICE_CURRENCY_CODE 
	,TASK_BILLABLE_FLAG 
	,TASK_START_DATE 
	,TASK_COMPLETION_DATE 
	,TASK_NUMBER 
	,INVOICEDSTATUS 
	,TASK_NAME 
	,PROJECT_START_DATE 
	,EVNT_COMPLETION_DATE 
    ,EVENT_INTERNAL_COMMENT 
    ,EVENT_DESC 
	,SESSION_ID 
) 
SELECT  
PROJECT_ID 
	,SEGMENT1 
	,PROJECT_STATUS_CODE 
	,PROJECT_NAME 
	,EVENT_ID 
	,EVENT_NUM 
	,EVENT_TYPE_CODE 
	,BILL_TRNS_AMOUNT 
	,BILL_TRNS_CURRENCY_CODE 
	,BILL_HOLD_FLAG 
	,REVENUE_HOLD_FLAG 
	,INVOICE_CURRENCY_CODE 
	,TASK_BILLABLE_FLAG 
	,TASK_START_DATE 
	,TASK_COMPLETION_DATE 
	,TASK_NUMBER 
	,INVOICEDSTATUS 
	,TASK_NAME 
	,PROJECT_START_DATE 
	,EVNT_COMPLETION_DATE 
    ,EVENT_INTERNAL_COMMENT 
    ,EVENT_DESC 
	,V('APP_SESSION') 
FROM   
       XMLTABLE('/DATA_DS/G_PROJECT_EVENTS' 
         PASSING XMLTYPE(l_report_decode) 
         COLUMNS  
                 PROJECT_ID PATH 'PROJECT_ID' 
                ,SEGMENT1 PATH 'SEGMENT1' 
                ,PROJECT_STATUS_CODE PATH 'PROJECT_STATUS_CODE' 
                ,PROJECT_NAME PATH 'PROJECT_NAME' 
                ,EVENT_ID PATH 'EVENT_ID' 
                ,EVENT_NUM PATH 'EVENT_NUM' 
                ,EVENT_TYPE_CODE PATH 'EVENT_TYPE_CODE' 
                ,BILL_TRNS_AMOUNT PATH 'BILL_TRNS_AMOUNT' 
                ,BILL_TRNS_CURRENCY_CODE PATH 'BILL_TRNS_CURRENCY_CODE' 
                ,BILL_HOLD_FLAG PATH 'BILL_HOLD_FLAG' 
                ,REVENUE_HOLD_FLAG PATH 'REVENUE_HOLD_FLAG' 
                ,INVOICE_CURRENCY_CODE PATH 'INVOICE_CURRENCY_CODE' 
                ,TASK_BILLABLE_FLAG PATH 'TASK_BILLABLE_FLAG' 
                ,TASK_START_DATE PATH 'TASK_START_DATE' 
                ,TASK_COMPLETION_DATE PATH 'TASK_COMPLETION_DATE' 
                ,TASK_NUMBER PATH 'PROTASK_NUMBERJECT_ID' 
                ,INVOICEDSTATUS PATH 'INVOICEDSTATUS' 
                ,TASK_NAME PATH 'TASK_NAME' 
                ,PROJECT_START_DATE PATH 'PROJECT_START_DATE' 
                ,EVNT_COMPLETION_DATE PATH 'EVNT_COMPLETION_DATE' 
                ,EVENT_INTERNAL_COMMENT PATH 'EVENT_INTERNAL_COMMENT' 
                ,EVENT_DESC PATH 'EVENT_DESC' 
	 
         ) xt; 
   
 insert into axxml_tab (id, vc2_data) values (6, 'PROC_UPDATE_STATUS End '); 
end;
/