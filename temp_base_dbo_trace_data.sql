BEGIN;

DROP TABLE IF EXISTS wpd.temps_base_mini_code_mapping;

CREATE UNLOGGED TABLE wpd.temps_base_mini_code_mapping
TABLESPACE data_tmps
AS
SELECT *
FROM dwd.t_trace_code_packing_mini_code_mapping;

CREATE INDEX idx_temps_base_mini_code_mapping_level1
    ON wpd.temps_base_mini_code_mapping (mini_code)
    TABLESPACE data_tmps;
CREATE INDEX idx_temps_base_mini_code_mapping_level2
    ON wpd.temps_base_mini_code_mapping (level2_trac_code)
    TABLESPACE data_tmps;
CREATE INDEX idx_temps_base_mini_code_mapping_level3
    ON wpd.temps_base_mini_code_mapping (level3_trac_code)
    TABLESPACE data_tmps;

ANALYZE wpd.temps_base_mini_code_mapping;

CREATE INDEX IF NOT EXISTS idx_temp_t1t2_group_list_code
    ON wpd.temp_t1t2_group_list (code)
    TABLESPACE data_tmps;

ANALYZE wpd.temp_t1t2_group_list;

DROP TABLE IF EXISTS wpd.temps_base_dbo_trace_data;

CREATE TABLE wpd.temps_base_dbo_trace_data
TABLESPACE data_tmps
AS
SELECT
    d.std_bill_ym,
    d.bill_time,
    d.bill_type,
    CASE
        WHEN d.bill_type IN (
            '销售出库', '退货出库', 'B2C出库', '供应出库', '其他出库',
            '召回出库', '直调出库', '调拨出库', '赠品出库', '零头出库'
        )
            THEN COALESCE(NULLIF(d.std_a_company_code, ''), d.std_f_company_code)
        ELSE d.std_f_company_code
    END AS std_f_company_code,
    CASE
        WHEN d.bill_type IN (
            '销售出库', '退货出库', 'B2C出库', '供应出库', '其他出库',
            '召回出库', '直调出库', '调拨出库', '赠品出库', '零头出库'
        )
            THEN CASE
                WHEN NULLIF(d.std_a_company_code, '') IS NOT NULL
                    THEN d.std_a_company_name
                ELSE d.std_f_company_name
            END
        ELSE d.std_f_company_name
    END AS std_f_company_name,
    CASE
        WHEN d.bill_type IN (
            '采购入库', '退货入库', '供应入库', '其他入库', '召回入库',
            '报废入库', '盘盈入库', '调拨入库', '赠品入库', '零头入库'
        )
            THEN COALESCE(NULLIF(d.std_a_company_code, ''), d.std_t_company_code)
        ELSE d.std_t_company_code
    END AS std_t_company_code,
    CASE
        WHEN d.bill_type IN (
            '采购入库', '退货入库', '供应入库', '其他入库', '召回入库',
            '报废入库', '盘盈入库', '调拨入库', '赠品入库', '零头入库'
        )
            THEN CASE
                WHEN NULLIF(d.std_a_company_code, '') IS NOT NULL
                    THEN d.std_a_company_name
                ELSE d.std_t_company_name
            END
        ELSE d.std_t_company_name
    END AS std_t_company_name,
    d.std_a_company_code,
    d.std_a_company_name,
    d.produce_batch_no,
    d.std_product_code,
    d.std_product_name,
    d.drug_key,
    g.product_group,
    d.create_time,
    d.update_date,
    d.least_pkg_amount,
    d.valid_end_date
FROM stda.t_trace_cdmorganondatacenter_dbo_trace_data AS d
JOIN stda.billing_product_group_list AS g
    ON g.org_code = d.std_product_code
WHERE d.std_product_code NOT IN (
        '86003391', '86000005', '86061939', '100033268', '100033269'
    )
    -- 源字段可能是文本，保留显式转换以维持原脚本的比较语义。
    AND d.create_time::timestamp <= TIMESTAMP '2026-08-07 00:00:00'
    AND d.update_date::timestamp <= TIMESTAMP '2026-08-07 00:00:00'
    AND d.std_bill_ym IN (
        '202510', '202511', '202512',
        '202601', '202602', '202603', '202604', '202605', '202606'
    );

-- 后续查询仅使用 drug_key 索引；不再创建随后立即删除的公司编码索引。
CREATE INDEX idx_temps_base_dbo_trace_data_drug_key
    ON wpd.temps_base_dbo_trace_data (drug_key)
    TABLESPACE data_tmps;

ANALYZE wpd.temps_base_dbo_trace_data;

COMMIT;
