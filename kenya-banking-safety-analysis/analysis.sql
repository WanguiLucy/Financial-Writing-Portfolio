  
/* Is your Bank Safe? */

--Market Control
select
	cms.bank_name ,
	cms.total_assets_ksh_m ,
	cms.deposit_accounts,
	cms.total_deposits_ksh_m
from
	cbk_market_share_2024 cms
order by
	cms.total_assets_ksh_m desc ;


--KCB, Equity, and Co-operative banks are the top banks by assets and control over 40% market shares.


--Safety Metrics:
 
--A. Capital Adequacy
select
	*
from
	cbk_capital_adequacy_2024 cca
where
	 cca.core_capital_to_rwa_pct <10.5
	or total_capital_to_rwa_pct < 14.5
	or cca.core_capital_to_deposits_pct < 8
;

-- 12 banks violated the capital adequacy minimum requirement.
--Core Capital to RWA : Can the bank survive a crisis?
--Core Capital to Deposits : Is your savings protected?

--B. Loans
 select
	cnl.bank_name ,
	cnl.npl_ratio_pct
from
	cbk_npl_loans_2024 cnl
where
	cnl.npl_ratio_pct > 5
;
 
-- 37 banks breached the 5% NPL threshold. Only 2 banks were below it.
--NPL Ratio : Are borrowers paying back the loans? 


--C. Profitability Coverage
select
	cp.bank_name ,cp.profit_before_tax_ksh_m , cp.return_on_assets_pct as ROA_pct
from
	cbk_profitability_2024 cp where cp.return_on_assets_pct < 0
order by
	cp.profit_before_tax_ksh_m asc ;

--ROA : Is the bank healthy and profitable?
--There are 10 banks with a negative ROA.


--Metric Normalization
with npl_score as (
select
	cnl.bank_name,
	cnl.npl_ratio_pct ,
	1 - ((cnl.npl_ratio_pct - min(cnl.npl_ratio_pct)over())
	/ nullif(max(cnl.npl_ratio_pct) over() - min(cnl.npl_ratio_pct) over(), 0)) as norm_npl
from
	cbk_npl_loans_2024 cnl 
),
core_capital_score as (
select
	cca.bank_name ,
	cca.core_capital_to_rwa_pct ,
	(cca.core_capital_to_rwa_pct - min(cca.core_capital_to_rwa_pct) over()) 
	/ nullif(max(cca.core_capital_to_rwa_pct) over() - min(cca.core_capital_to_rwa_pct) over(), 0) as norm_core_capital
from
	cbk_capital_adequacy_2024 cca 
),
total_capital_score as (
select
	cca.bank_name ,
	cca.total_capital_to_rwa_pct,
	(cca.total_capital_to_rwa_pct - min(cca.total_capital_to_rwa_pct) over()) 
	/ nullif(max(cca.total_capital_to_rwa_pct) over() - min(cca.total_capital_to_rwa_pct) over(), 0) as norm_total_capital
from
	cbk_capital_adequacy_2024 cca 
),
capital_deposits_score as (
select
	cca.bank_name,
	cca.core_capital_to_deposits_pct,
	(cca.core_capital_to_deposits_pct - min(cca.core_capital_to_deposits_pct) over()) 
	/ nullif(max(cca.core_capital_to_deposits_pct) over() - min(cca.core_capital_to_deposits_pct) over(), 0) as norm_capital_deposits
from
	cbk_capital_adequacy_2024 cca 
),
ROA_score as (
select
	cp.bank_name,
	cp.return_on_assets_pct,
	(case
		when cp.return_on_assets_pct < -15 then -15
		else cp.return_on_assets_pct
	end - min(case when cp.return_on_assets_pct < -15 then -15
                    else cp.return_on_assets_pct end) over())
    / nullif(
        max(case when cp.return_on_assets_pct < -15 then -15
                 else cp.return_on_assets_pct end) over()
        - min(case when cp.return_on_assets_pct < -15 then -15
                   else cp.return_on_assets_pct end) over()
      , 0) as norm_ROA
from
	cbk_profitability_2024 cp
),
classification as(
select
	n.bank_name ,
	round(n.norm_npl, 2) as npl_score ,
	round(cc.norm_core_capital, 2) as core_capital_score ,
	round(tc.norm_total_capital, 2) as total_capital_score ,
	round(cd.norm_capital_deposits, 2) as capital_deposits_score,
	round(rs.norm_ROA, 2) as ROA_score,
	round((n.norm_npl * 0.15 + cc.norm_core_capital * 0.25 + tc.norm_total_capital * 0.25 + cd.norm_capital_deposits * 0.25 + rs.norm_ROA * 0.10), 2) as composite_score	
from
	npl_score n
join core_capital_score cc on
	n.bank_name = cc.bank_name
join total_capital_score tc on
	n.bank_name = tc.bank_name
join capital_deposits_score cd on
	n.bank_name = cd.bank_name
join ROA_score rs on
	n.bank_name = rs.bank_name),
ranked as (
select
	*,
	rank() over(order by composite_score desc) as safety_rank
from
	classification
)
select
		*,
	case
		when composite_score >= (
		select
			avg(c2.composite_score) + 0.5 * sqrt(avg(c2.composite_score * c2.composite_score) - avg(c2.composite_score) * avg(c2.composite_score))
		from
			classification c2
        ) then 'Safe'
		when composite_score >= (
		select
			avg(c2.composite_score) - 0.5 * sqrt(avg(c2.composite_score * c2.composite_score) - avg(c2.composite_score) * avg(c2.composite_score))
		from
			classification c2
        ) then 'Watch'
		else 'Concern'
	end as bank_status_tier
from
	ranked;





