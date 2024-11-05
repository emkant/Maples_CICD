CREATE OR REPLACE EDITIONABLE PROCEDURE "APEX_PROC_POC" (p_project_number in varchar2)  
 is  
  
  l_url varchar2(4000) ;  
  name varchar2(4000);  
  buffer varchar2(4000);   
  l_envelope varchar2(4000);  
  p_username varchar2(4000);  
  p_password varchar(4000);  
  l_response_xml        XMLTYPE;  
  p_nic_number varchar2(100);  
  l_version varchar2(1000);  
  l_report_response varchar2(10000);  
  l_report_decode varchar2(10000);  
  l_temp varchar2(10000) ;  
    
 begin  
   
p_username := 'casey.brown';  
p_password := 'aKp63539';  
l_version := '1.2';  
  
l_url := 'https://ucf3-zoqc-fa-ext.oracledemos.com:443/xmlpserver/services/ExternalReportWSSService';  
   
 l_envelope := '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">  
   <soap:Header/>  
   <soap:Body>  
      <pub:runReport>  
         <pub:reportRequest>  
           <pub:attributeFormat>xml</pub:attributeFormat>  
            <pub:reportAbsolutePath>/Custom/Procurement/Purchasing/SupplierSampleRpt.xdo</pub:reportAbsolutePath>  
            <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>  
         </pub:reportRequest>  
         <pub:appParams></pub:appParams>  
      </pub:runReport>  
   </soap:Body>  
</soap:Envelope>';  
  
     /*  
      apex_web_service.g_request_headers(1).name  := 'Content-Encoding';  
      apex_web_service.g_request_headers(1).value := 'gzip' ;  
      apex_web_service.g_request_headers(2).name  := 'Content-Language';  
      apex_web_service.g_request_headers(2).value := 'en' ;  
      apex_web_service.g_request_headers(3).name  := 'Content-Length';  
      apex_web_service.g_request_headers(4).value := '1142' ;  
      apex_web_service.g_request_headers(5).name  := 'Connection';  
      apex_web_service.g_request_headers(6).value := 'keep-alive' ;  
      apex_web_service.g_request_headers(7).name  := 'Vary';  
      apex_web_service.g_request_headers(8).value := 'Accept-Encoding' ;  
       
      apex_web_service.g_request_headers(1).name  := 'Content-Type';  
      apex_web_service.g_request_headers(1).value := 'application/soap+xml' ;  
     */  
       
   
  l_response_xml  :=   apex_web_service.make_request(  
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
   
 insert into axxml_tab (id, vc2_data) values (3, l_report_response);  
   
  l_temp := substr(l_report_response, instr(l_report_response,'>') +1,instr(substr(l_report_response, instr(l_report_response,'>') +1),'</ns2:report')-1);  
  l_report_response := l_temp;  
    
--l_report_response := 'PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPCEtLUdlbmVyYXRlZCBieSBPcmFjbGUgQkkgUHVibGlzaGVyIC1EYXRhZW5naW5lLCBkYXRhbW9kZWw6X0N1c3RvbV9Qcm9jdXJlbWVudF9QdXJjaGFzaW5nX1N1cHBsaWVyU2FtcGxlX3hkbSAtLT4KPERBVEFfRFM+CjxHXzE+CjxTVVBQTElFUl9OVU1CRVI+MTI1MjwvU1VQUExJRVJfTlVNQkVSPjxTVVBQTElFUl9OQU1FPkxlZSBTdXBwbGllczwvU1VQUExJRVJfTkFNRT4KPC9HXzE+CjxHXzE+CjxTVVBQTElFUl9OVU1CRVI+MTI1MzwvU1VQUExJRVJfTlVNQkVSPjxTVVBQTElFUl9OQU1FPlN0YWZmaW5nIFNlcnZpY2VzPC9TVVBQTElFUl9OQU1FPgo8L0dfMT4KPC9EQVRBX0RTPg==';  
   
   
 l_report_decode := utl_raw.cast_to_varchar2(utl_encode.base64_decode(utl_raw.cast_to_raw(l_report_response)));  
   
  insert into axxml_tab (id, vc2_data) values (4, l_report_decode);  
   
 insert into AXGPMC_EXPENSES  
(  
PROJECT_NUMBER,  
EXPENSE_TYPE,  
EXPENSE_COST,  
SESSION_ID,  
STATUS  
)  
SELECT xt.supplier_number, xt.supplier_name, 100, V('APP_SESSION'), 'Y'  
FROM   AXXML_TAB x,   
       XMLTABLE('/DATA_DS/G_1'  
         PASSING x.xml_data  
         COLUMNS   
           supplier_number     VARCHAR2(40)  PATH 'SUPPLIER_NUMBER',  
           supplier_name     VARCHAR2(100) PATH 'SUPPLIER_NAME'  
         ) xt  
         where x.id = 4;  
  
   
  
  
  p_nic_number := p_project_number;  
    
  l_url := 'https://ucf3-zoqc-fa-ext.oracledemos.com:443/fscmService/SupplierServiceV2';  
  
  l_envelope := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:typ="http://xmlns.oracle.com/apps/prc/poz/suppliers/supplierServiceV2/types/" xmlns:sup="http://xmlns.oracle.com/apps/prc/poz/suppliers/supplierServiceV2/" xmlns:sup1="http://xmlns.oracle.com/apps/flex/prc/poz/suppliers/supplierServiceV2/supplierSites/" xmlns:sup2="http://xmlns.oracle.com/apps/flex/prc/poz/suppliers/supplierServiceV2/supplierAddress/" xmlns:sup3="http://xmlns.oracle.com/apps/flex/prc/poz/suppliers/supplierServiceV2/supplier/" xmlns:sup4="http://xmlns.oracle.com/apps/flex/prc/poz/suppliers/supplierServiceV2/supplierContact/">  
   <soapenv:Header/>  
   <soapenv:Body>  
      <typ:updateSupplier>  
         <typ:supplierRow>  
            <sup:SupplierId>300000047414503</sup:SupplierId>  
            <sup:SupplierNumber>1252</sup:SupplierNumber>  
            <sup:NationalInsuranceNumber>' || p_nic_number || '</sup:NationalInsuranceNumber>  
         </typ:supplierRow>  
      </typ:updateSupplier>  
   </soapenv:Body>  
</soapenv:Envelope>';  
  
  insert into axxml_tab (id, vc2_data) values (0, l_envelope);  
  
    --  apex_web_service.g_request_headers.delete;  
        
        
  l_response_xml  :=   apex_web_service.make_request(  
            p_url      => l_url,  
            p_envelope => l_envelope,  
            p_username => p_username,  
            p_password => p_password);  
    
    
  insert into axxml_tab (id, xml_data) values (1, l_response_xml);  
  
  
end;
/