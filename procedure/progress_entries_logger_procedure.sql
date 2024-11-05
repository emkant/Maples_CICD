CREATE OR REPLACE EDITIONABLE PROCEDURE "PROGRESS_ENTRIES_LOGGER" 
(p_percentage in number,
p_message in varchar2)
is
pragma autonomous_transaction;
begin
insert into progress_entries (percentage,message,created_date) values (p_percentage,p_message,systimestamp);
commit;
end;
/