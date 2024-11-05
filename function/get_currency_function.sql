CREATE OR REPLACE EDITIONABLE FUNCTION "GET_CURRENCY" (p_currency_code in varchar2)
return varchar2 
is 
  v_currency varchar2(1000);
begin
  select case p_currency_code 
  when  'USD' then  '$' 
  when    'EUR' then  '€' 
  when    'CRC' then  '₡' 
  when    'GBP' then  '£' 
  when    'ILS' then  '₪' 
  when    'INR' then  '₹' 
  when    'JPY' then  '¥' 
  when    'KRW' then  '₩' 
  when    'NGN' then  '₦' 
  when    'PHP' then  '₱' 
  when    'PLN' then  'zł'
  when    'PYG' then  '₲'
  when    'THB' then  '฿'
  when    'UAH' then  '₴' 
  when    'VND' then  '₫'
   end cur 
   into v_currency
   from dual;
   return v_currency;
 end;
/