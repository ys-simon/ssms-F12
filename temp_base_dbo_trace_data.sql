SELECT * FROM wpd.temps_base_mini_code_mapping limit 10;

DROP TABLE IF EXISTS wpd.temps_base_mini_code_mapping;
CREATE UNLOGGED TABLE wpd.temps_base_mini_code_mapping TABLESPACE data_tmps as 
    SELECT * FROM dwd.t_trace_code_packing_mini_code_mapping;

CREATE INDEX IF NOT EXISTS idx_temps_base_mini_code_mapping_level1 ON wpd.temps_base_mini_code_mapping (mini_code) TABLESPACE data_tmps;
CREATE INDEX IF NOT EXISTS idx_temps_base_mini_code_mapping_level2 ON wpd.temps_base_mini_code_mapping(level2_trac_code) TABLESPACE data_tmps;
CREATE INDEX IF NOT EXISTS idx_temps_base_mini_code_mapping_level3 ON wpd.temps_base_mini_code_mapping(level3_trac_code) TABLESPACE data_tmps;
ANALYZE wpd.temps_base_mini_code_mapping;

CREATE INDEX IF NOT EXISTS idx_temp_t1t2_group_list_code ON wpd.temp_t1t2_group_list(code) TABLESPACE data_tmps;
ANALYZE wpd.temp_t1t2_group_list;


SELECT * FROM wpd.temps_base_dbo_trace_data limit 10;
DROP TABLE IF EXISTS wpd.temps_base_dbo_trace_data;
CREATE TABLE wpd.temps_base_dbo_trace_data TABLESPACE data_tmps as
SELECT d.std_bill_ym, d.bill_time, d.bill_type
    , case when d.bill_type IN ('销售出库','退货出库','B2C出库','供应出库','其他出库','召回出库','直调出库','调拨出库','赠品出库','零头出库')
        then case when COALESCE(d.std_a_company_code, '') <> '' then d.std_a_company_code else d.std_f_company_code end
        else d.std_f_company_code
        end as std_f_company_code
    , case when d.bill_type IN ('销售出库','退货出库','B2C出库','供应出库','其他出库','召回出库','直调出库','调拨出库','赠品出库','零头出库')
        then case when COALESCE(d.std_a_company_code, '') <> '' then d.std_a_company_name else d.std_f_company_name end
        else d.std_f_company_name
        end as std_f_company_name
    , case when d.bill_type IN ('采购入库','退货入库','供应入库','其他入库','召回入库','报废入库','盘盈入库','调拨入库','赠品入库','零头入库')
        then case when COALESCE(d.std_a_company_code, '') <> '' then d.std_a_company_code else d.std_t_company_code end
        else d.std_t_company_code
        end as std_t_company_code
    , case when d.bill_type IN ('采购入库','退货入库','供应入库','其他入库','召回入库','报废入库','盘盈入库','调拨入库','赠品入库','零头入库')
        then case when COALESCE(d.std_a_company_code, '') <> '' then d.std_a_company_name else d.std_t_company_name end
        else d.std_t_company_name
        end as std_t_company_name
    , d.std_a_company_code, d.std_a_company_name
    , d.produce_batch_no, d.std_product_code, d.std_product_name
    , d.drug_key, g.product_group, d.create_time, d.update_date, d.least_pkg_amount, d.valid_end_date
FROM stda.t_trace_cdmorganondatacenter_dbo_trace_data d 
INNER join stda.billing_product_group_list g on g.org_code = d.std_product_code
WHERE d.std_product_code not in ('86003391','86000005','86061939','100033268','100033269')
    -- and d.std_bill_ym = ANY(v_bill_yms) and (d.create_time::timestamp <= v_as_of_time and d.update_date::timestamp <= v_as_of_time)
    and (d.create_time::timestamp <= '2026-08-07' and d.update_date::timestamp <= '2026-08-07')
    -- and d.std_bill_ym = ANY(string_to_array('202501,202502,202503,202504,202505,202506,202507,202508,202509,202510,202511,202512,202601,202602,202603,202604,202605,202606', ',')) 
    and d.std_bill_ym = ANY(string_to_array('202510,202511,202512,202601,202602,202603,202604,202605,202606', ','))
;
CREATE INDEX IF NOT EXISTS idx_temps_base_dbo_trace_data_drug_key ON wpd.temps_base_dbo_trace_data (drug_key) TABLESPACE data_tmps;
CREATE INDEX IF NOT EXISTS idx_temps_base_dbo_trace_data_f_company ON wpd.temps_base_dbo_trace_data(std_f_company_code) TABLESPACE data_tmps;
CREATE INDEX IF NOT EXISTS idx_temps_base_dbo_trace_data_t_company ON wpd.temps_base_dbo_trace_data(std_t_company_code) TABLESPACE data_tmps;
ANALYZE wpd.temps_base_dbo_trace_data;

DROP index wpd.idx_temps_base_dbo_trace_data_f_company;
DROP index wpd.idx_temps_base_dbo_trace_data_t_company;

--select * from wpd.temps_base_dbo_trace_data d limit 10;

    -- WITH sales as (
    --     SELECT *
    --     FROM wpd.temps_base_dbo_trace_data d
    --     WHERE EXISTS(
    --             SELECT 1 FROM wpd.temp_t1t2_group_list b 
    --             WHERE b.flag = 1 and (b.code = d.std_f_company_code or b.code = d.std_t_company_code or b.code = d.std_a_company_code)
    --         )
    -- )
    -- SELECT c.code as code_src, d.*, t.trac_code, t.code_level --, v_as_of_time as last_update_date, now() as last_exec_time
    -- FROM sales d
    -- inner join stda.t_trace_traceabilitydata_data_trace_code t on d.drug_key = t.drug_key
    -- INNER JOIN wpd.temp_t1t2_group_list c ON c.flag = 1 and (c.code = d.std_f_company_code or c.code = d.std_t_company_code)
    -- WHERE COALESCE(d.std_f_company_code,'') <> COALESCE(d.std_t_company_code,'')
    -- limit 10;
