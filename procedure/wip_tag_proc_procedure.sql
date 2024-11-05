CREATE OR REPLACE EDITIONABLE PROCEDURE "WIP_TAG_PROC" (p_expenditure_item_list in varchar2, 
                                  p_project_number in varchar2, 
                                  p_adj_pct in number, 
                                  p_adj_amt in number, 
                                  p_sel_amt in number) 
IS 
        input_str        VARCHAR2(4000); 
        var1             VARCHAR2(100); 
        temp_str         VARCHAR2(4000); 
        exp_id           VARCHAR2(100); 
        p_project_bill_rate_attr NUMBER; 
        p_project_bill_rate_amt NUMBER; 
        p_project_exp_qty NUMBER; 
        p_amt_red  NUMBER; 
        p_new_amt  NUMBER; 
        p_new_pct NUMBER; 
        p_project_amt_pct NUMBER; 
         
BEGIN 
                INSERT INTO axxml_tab 
                ( 
                        id, 
                        vc2_data 
                ) 
                VALUES 
                ( 
                        600, 
                        'WIP EXP ITEMS: ' 
                                ||p_expenditure_item_list 
                ); 
                 
                  
                  
                 input_str := p_expenditure_item_list;  
    
                 var1 := instr(input_str,'-',1,2);  
  
                 while (var1 > 0)  
                 loop  
                        temp_str := substr(input_str,2, var1-2);  
                        exp_id := temp_str;  
                         
                        if (p_adj_pct <> 0) then 
                         
                            UPDATE XXGPMS_PROJECT_COSTS 
                            SET REALIZED_BILL_RATE_ATTR = PROJECT_BILL_RATE_ATTR - (PROJECT_BILL_RATE_ATTR * P_ADJ_PCT/100), 
                                REALIZED_BILL_RATE_AMT = QUANTITY * (PROJECT_BILL_RATE_ATTR - (PROJECT_BILL_RATE_ATTR * P_ADJ_PCT/100)) 
                            WHERE EXPENDITURE_ITEM_ID = exp_id; 
                        else 
                         
                            p_project_bill_rate_attr := 0; 
                            p_project_bill_rate_amt := 0; 
                            p_project_exp_qty := 0; 
                            p_amt_red  := 0; 
                            p_new_amt  := 0; 
                            p_new_pct := 0; 
                            p_project_amt_pct := 0; 
         
         
                              SELECT PROJECT_BILL_RATE_ATTR, 
                                   PROJECT_BILL_RATE_AMT, 
                                   QUANTITY 
                              INTO 
                                   p_project_bill_rate_attr, 
                                   p_project_bill_rate_amt, 
                                   p_project_exp_qty 
                              FROM XXGPMS_PROJECT_COSTS 
                             WHERE EXPENDITURE_ITEM_ID = exp_id; 
                                    
                             p_project_amt_pct := p_project_bill_rate_amt*100/p_sel_amt; 
                             p_amt_red := p_adj_amt * p_project_amt_pct/100; 
                             p_new_amt := p_project_bill_rate_amt - p_amt_red; 
                             p_new_pct := p_new_amt/p_project_exp_qty ; 
                              
                             UPDATE XXGPMS_PROJECT_COSTS 
                             SET REALIZED_BILL_RATE_ATTR = p_new_pct, 
                                 REALIZED_BILL_RATE_AMT = p_new_amt 
                             WHERE EXPENDITURE_ITEM_ID = exp_id; 
                             
                        end if; 
                         
                         
                        input_str := substr(input_str,var1,100);  
                        var1 := instr(input_str,'-',1,2);  
                         
                 end loop;  
end; 
/