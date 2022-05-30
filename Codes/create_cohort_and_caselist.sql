
--Check change in CAD record numbers over time, and where dispatch code is MH
SELECT *
from(
SELECT year(INCIDENT_DTTM) AS Yr, count(INCIDENT_DTTM )
FROM SAIL1330V.WASD_AMBULANCECADINCIDENT_20210917
WHERE incident_dttm BETWEEN '2016-01-01' AND '2020-12-31'
GROUP BY year(INCIDENT_DTTM)
ORDER BY year(INCIDENT_DTTM )
) a INNER JOIN (
SELECT year(INCIDENT_DTTM) AS Yr, count(INCIDENT_DTTM )
FROM SAIL1330V.WASD_AMBULANCECADINCIDENT_20210917 cad
	LEFT JOIN SAILW1330V.LB_AMPDS_MH_CODES ampds_lku ON ampds_lku.ampds_cd = cad.DISPATCH_CD_ANDSUFFIX 
WHERE incident_dttm BETWEEN '2016-01-01' AND '2020-12-31'
	AND AMPDS_CD IS NOT null
GROUP BY year(INCIDENT_DTTM)
ORDER BY year(INCIDENT_DTTM )
) b ON a.yr = b.yr

SELECT *
FROM SAIL1330V.WASD_AMBULANCECADINCIDENT_20210917

SELECT *
FROM SAILW1330V.LB_AMPDS_MH_CODES


----------------------------------------------------------------------------------------------

--COHORT

DROP TABLE sailw1330v.DF_COHORT_LONG 	

CREATE TABLE sailW1330v.df_cohort_long (
	alf_pe bigint,
	gndr_cd int,
	wob date,
	turn11 date,
	turn25 date,
	start_date date,
	end_date date,
	start_date1 date,
	end_date1 date,
	death_dt date,
	end_date2 date,
	ageforyr int,
	persondays int,
	lsoa2011_cd varchar(10),
	overall_quintile int,
	ruc11cd varchar(5)
	)
 
	
INSERT INTO sailW1330v.df_cohort_long
--For each year get cohort and union them together. Then outer query joins WIMD and rural from lookup tables
SELECT cohort.alf_pe, cohort.gndr_cd, cohort.wob, cohort.turn11, cohort.turn25, cohort.start_date, cohort.end_date,
	cohort.start_date1, cohort.end_date1, cohort.death_dt, cohort.end_date2, cohort.ageforyr, 
	(DAYS(end_date2) - DAYS (start_date1)) + 1 AS persondays, cohort.lsoa2011_cd, wimd.OVERALL_QUINTILE, rural.ruc11cd
FROM (
	--get cases for each year and union them together
	----2016 cases----
	--get the first age and lsoa for each patient for this year
	SELECT *,
		2016 - year(wob) AS ageforyr
		--first_value(age) over(PARTITION BY ALF_PE ORDER BY START_DATE1) AS ageForYr
	FROM (
		--calculate age at start date
		--update end_date1 with death_dt
		SELECT *, 
			years_between(START_DATE1, wob) AS age,
			CASE WHEN death_dt BETWEEN START_DATE1 AND END_DATE1 THEN death_dt ELSE end_date1 END AS end_DATE2
		FROM (
			--limit to people who were between 11-24 during study period
			--update start_date and end_date to accommodate turning 11 or 25 midway through year
		SELECT cases.alf_pe AS alf, cases.gndr_cd, cases.wob, cases.turn11, cases.turn25, START_date, end_date,
				CASE WHEN cases.turn11 BETWEEN cases.START_DATE AND cases.END_DATE THEN cases.turn11 ELSE cases.start_date END AS START_DATE1,
				CASE WHEN cases.turn25-1 BETWEEN cases.START_DATE AND cases.END_DATE THEN cases.turn25-1 ELSE cases.end_date END AS end_DATE1,
				cases.death_dt
			FROM (
				--cut-off start/end dates to only cover this year
				SELECT addr.*, age.gndr_cd, age.wob, age.turn11, age.turn25, deaths.death_dt
				FROM (
					--select records with addresses in study period and join to demogs
					SELECT alf_pe, max(START_DATE, '2016-01-01') AS start_date, min(END_DATE, '2016-12-31') AS end_date
					FROM SAIL1330V.WDSD_CLEAN_ADD_WALES_20210704
					WHERE '2016-01-01' <= end_date AND '2016-12-31' >= START_DATE
						and welsh_address = 1
					) addr
				INNER JOIN (
					--select demogs and calc when they turn11 and turn25 (enter and leave the cohort)
					SELECT ALF_PE, gndr_cd, wob, add_years(wob, 11) AS turn11, add_years(wob, 25) AS turn25
					FROM SAIL1330V.WDSD_AR_PERS_20210704
					) age ON age.ALF_PE = addr.ALF_PE
				left JOIN (
					SELECT alf_pe, death_dt 
					FROM SAIL1330V.ADDE_DEATHS_20210628
					WHERE ALF_STS_CD  IN (1,4,39)
					) deaths ON deaths.alf_pe = addr.alf_pe
				) cases
			--only keep records where the time period of being 11-24 overlaps with the start/end dates of that address
			where turn11 <= end_date AND turn25 - 1 >= start_date	
		)
	) 
	INNER JOIN (
			--for each patient, number lsoa's in date order
			SELECT ALF_PE, LSOA2011_cd
			FROM (
				SELECT ALF_PE, lsoa2011_cd, row_number() over(PARTITION BY ALF_PE ORDER BY START_DATE) AS rn
				FROM (
					SELECT ALF_PE, LSOA2011_CD,
						CASE WHEN turn11 BETWEEN START_DATE AND END_DATE THEN turn11 ELSE START_DATE END AS start_date,
						END_DATE
					FROM (
						SELECT *
						FROM (
							SELECT ad.ALF_PE, LSOA2011_CD,
								max(START_DATE, '2016-01-01') AS START_DATE, min(END_DATE, '2016-12-31') AS end_Date,
								add_years(wob, 11) AS turn11, add_years(wob, 25) AS turn25
							FROM SAIL1330V.WDSD_CLEAN_ADD_GEOG_CHAR_LSOA2011_20210704 ad
								LEFT JOIN SAIL1330V.WDSD_AR_PERS_20210704 age ON ad.ALF_PE = age.ALF_PE
							)
						WHERE '2016-01-01' <= END_DATE AND '2016-12-31' >= START_DATE
							AND turn11 <= end_date
						)		
					)
				)
			WHERE rn = 1 
			)lsoa ON alf = lsoa.ALF_PE
	UNION ALL
	----2017 cases----
	--get the first age and lsoa for each patient for this year
	SELECT *,
		2017 - year(wob) AS ageforyr
		--first_value(age) over(PARTITION BY ALF_PE ORDER BY START_DATE1) AS ageForYr
	FROM (
		--calculate age at start date
		--update end_date1 with death_dt
		SELECT *, 
			years_between(START_DATE1, wob) AS age,
			CASE WHEN death_dt BETWEEN START_DATE1 AND END_DATE1 THEN death_dt ELSE end_date1 END AS end_DATE2
		FROM (
			--limit to people who were between 11-24 during study period
			--update start_date and end_date to accommodate turning 11 or 25 midway through year
		SELECT cases.alf_pe AS alf, cases.gndr_cd, cases.wob, cases.turn11, cases.turn25, START_date, end_date,
				CASE WHEN cases.turn11 BETWEEN cases.START_DATE AND cases.END_DATE THEN cases.turn11 ELSE cases.start_date END AS START_DATE1,
				CASE WHEN cases.turn25-1 BETWEEN cases.START_DATE AND cases.END_DATE THEN cases.turn25-1 ELSE cases.end_date END AS end_DATE1,
				cases.death_dt
			FROM (
				--cut-off start/end dates to only cover this year
				SELECT addr.*, age.gndr_cd, age.wob, age.turn11, age.turn25, deaths.death_dt
				FROM (
					--select records with addresses in study period and join to demogs
					SELECT alf_pe, max(START_DATE, '2017-01-01') AS start_date, min(END_DATE, '2017-12-31') AS end_date
					FROM SAIL1330V.WDSD_CLEAN_ADD_WALES_20210704
					WHERE '2017-01-01' <= end_date AND '2017-12-31' >= START_DATE
						and welsh_address = 1
					) addr
				INNER JOIN (
					--select demogs and calc when they turn11 and turn25 (enter and leave the cohort)
					SELECT ALF_PE, gndr_cd, wob, add_years(wob, 11) AS turn11, add_years(wob, 25) AS turn25
					FROM SAIL1330V.WDSD_AR_PERS_20210704
					) age ON age.ALF_PE = addr.ALF_PE
				left JOIN (
					SELECT alf_pe, death_dt 
					FROM SAIL1330V.ADDE_DEATHS_20210628
					WHERE ALF_STS_CD  IN (1,4,39)
					) deaths ON deaths.alf_pe = addr.alf_pe
				) cases
			--only keep records where the time period of being 11-24 overlaps with the start/end dates of that address
			where turn11 <= end_date AND turn25 - 1 >= start_date	
		)
	) 
	INNER JOIN (
			--for each patient, number lsoa's in date order
			SELECT ALF_PE, LSOA2011_cd
			FROM (
				SELECT ALF_PE, lsoa2011_cd, row_number() over(PARTITION BY ALF_PE ORDER BY START_DATE) AS rn
				FROM (
					SELECT ALF_PE, LSOA2011_CD,
						CASE WHEN turn11 BETWEEN START_DATE AND END_DATE THEN turn11 ELSE START_DATE END AS start_date,
						END_DATE
					FROM (
						SELECT *
						FROM (
							SELECT ad.ALF_PE, LSOA2011_CD,
								max(START_DATE, '2017-01-01') AS START_DATE, min(END_DATE, '2017-12-31') AS end_Date,
								add_years(wob, 11) AS turn11, add_years(wob, 25) AS turn25
							FROM SAIL1330V.WDSD_CLEAN_ADD_GEOG_CHAR_LSOA2011_20210704 ad
								LEFT JOIN SAIL1330V.WDSD_AR_PERS_20210704 age ON ad.ALF_PE = age.ALF_PE
							)
						WHERE '2017-01-01' <= END_DATE AND '2017-12-31' >= START_DATE
							AND turn11 <= end_date
						)		
					)
				)
			WHERE rn = 1 
			)lsoa ON alf = lsoa.ALF_PE
	UNION ALL
	----2018 cases----
	--get the first age and lsoa for each patient for this year
	SELECT *,
		2018 - year(wob) AS ageforyr
		--first_value(age) over(PARTITION BY ALF_PE ORDER BY START_DATE1) AS ageForYr
	FROM (
		--calculate age at start date
		--update end_date1 with death_dt
		SELECT *, 
			years_between(START_DATE1, wob) AS age,
			CASE WHEN death_dt BETWEEN START_DATE1 AND END_DATE1 THEN death_dt ELSE end_date1 END AS end_DATE2
		FROM (
			--limit to people who were between 11-24 during study period
			--update start_date and end_date to accommodate turning 11 or 25 midway through year
		SELECT cases.alf_pe AS alf, cases.gndr_cd, cases.wob, cases.turn11, cases.turn25, START_date, end_date,
				CASE WHEN cases.turn11 BETWEEN cases.START_DATE AND cases.END_DATE THEN cases.turn11 ELSE cases.start_date END AS START_DATE1,
				CASE WHEN cases.turn25-1 BETWEEN cases.START_DATE AND cases.END_DATE THEN cases.turn25-1 ELSE cases.end_date END AS end_DATE1,
				cases.death_dt
			FROM (
				--cut-off start/end dates to only cover this year
				SELECT addr.*, age.gndr_cd, age.wob, age.turn11, age.turn25, deaths.death_dt
				FROM (
					--select records with addresses in study period and join to demogs
					SELECT alf_pe, max(START_DATE, '2018-01-01') AS start_date, min(END_DATE, '2018-12-31') AS end_date
					FROM SAIL1330V.WDSD_CLEAN_ADD_WALES_20210704
					WHERE '2018-01-01' <= end_date AND '2018-12-31' >= START_DATE
						and welsh_address = 1
					) addr
				INNER JOIN (
					--select demogs and calc when they turn11 and turn25 (enter and leave the cohort)
					SELECT ALF_PE, gndr_cd, wob, add_years(wob, 11) AS turn11, add_years(wob, 25) AS turn25
					FROM SAIL1330V.WDSD_AR_PERS_20210704
					) age ON age.ALF_PE = addr.ALF_PE
				left JOIN (
					SELECT alf_pe, death_dt 
					FROM SAIL1330V.ADDE_DEATHS_20210628
					WHERE ALF_STS_CD  IN (1,4,39)
					) deaths ON deaths.alf_pe = addr.alf_pe
				) cases
			--only keep records where the time period of being 11-24 overlaps with the start/end dates of that address
			where turn11 <= end_date AND turn25 - 1 >= start_date	
		)
	) 
	INNER JOIN (
			--for each patient, number lsoa's in date order
			SELECT ALF_PE, LSOA2011_cd
			FROM (
				SELECT ALF_PE, lsoa2011_cd, row_number() over(PARTITION BY ALF_PE ORDER BY START_DATE) AS rn
				FROM (
					SELECT ALF_PE, LSOA2011_CD,
						CASE WHEN turn11 BETWEEN START_DATE AND END_DATE THEN turn11 ELSE START_DATE END AS start_date,
						END_DATE
					FROM (
						SELECT *
						FROM (
							SELECT ad.ALF_PE, LSOA2011_CD,
								max(START_DATE, '2018-01-01') AS START_DATE, min(END_DATE, '2018-12-31') AS end_Date,
								add_years(wob, 11) AS turn11, add_years(wob, 25) AS turn25
							FROM SAIL1330V.WDSD_CLEAN_ADD_GEOG_CHAR_LSOA2011_20210704 ad
								LEFT JOIN SAIL1330V.WDSD_AR_PERS_20210704 age ON ad.ALF_PE = age.ALF_PE
							)
						WHERE '2018-01-01' <= END_DATE AND '2018-12-31' >= START_DATE
							AND turn11 <= end_date
						)		
					)
				)
			WHERE rn = 1 
			)lsoa ON alf = lsoa.ALF_PE
	UNION ALL
	----2019 cases----
	--get the first age and lsoa for each patient for this year
	SELECT *,
		2019 - year(wob) AS ageforyr
		--first_value(age) over(PARTITION BY ALF_PE ORDER BY START_DATE1) AS ageForYr
	FROM (
		--calculate age at start date
		--update end_date1 with death_dt
		SELECT *, 
			years_between(START_DATE1, wob) AS age,
			CASE WHEN death_dt BETWEEN START_DATE1 AND END_DATE1 THEN death_dt ELSE end_date1 END AS end_DATE2
		FROM (
			--limit to people who were between 11-24 during study period
			--update start_date and end_date to accommodate turning 11 or 25 midway through year
		SELECT cases.alf_pe AS alf, cases.gndr_cd, cases.wob, cases.turn11, cases.turn25, START_date, end_date,
				CASE WHEN cases.turn11 BETWEEN cases.START_DATE AND cases.END_DATE THEN cases.turn11 ELSE cases.start_date END AS START_DATE1,
				CASE WHEN cases.turn25-1 BETWEEN cases.START_DATE AND cases.END_DATE THEN cases.turn25-1 ELSE cases.end_date END AS end_DATE1,
				cases.death_dt
			FROM (
				--cut-off start/end dates to only cover this year
				SELECT addr.*, age.gndr_cd, age.wob, age.turn11, age.turn25, deaths.death_dt
				FROM (
					--select records with addresses in study period and join to demogs
					SELECT alf_pe, max(START_DATE, '2019-01-01') AS start_date, min(END_DATE, '2019-12-31') AS end_date
					FROM SAIL1330V.WDSD_CLEAN_ADD_WALES_20210704
					WHERE '2019-01-01' <= end_date AND '2019-12-31' >= START_DATE
						and welsh_address = 1
					) addr
				INNER JOIN (
					--select demogs and calc when they turn11 and turn25 (enter and leave the cohort)
					SELECT ALF_PE, gndr_cd, wob, add_years(wob, 11) AS turn11, add_years(wob, 25) AS turn25
					FROM SAIL1330V.WDSD_AR_PERS_20210704
					) age ON age.ALF_PE = addr.ALF_PE
				left JOIN (
					SELECT alf_pe, death_dt 
					FROM SAIL1330V.ADDE_DEATHS_20210628
					WHERE ALF_STS_CD  IN (1,4,39)
					) deaths ON deaths.alf_pe = addr.alf_pe
				) cases
			--only keep records where the time period of being 11-24 overlaps with the start/end dates of that address
			where turn11 <= end_date AND turn25 - 1 >= start_date	
		)
	) 
	INNER JOIN (
			--for each patient, number lsoa's in date order
			SELECT ALF_PE, LSOA2011_cd
			FROM (
				SELECT ALF_PE, lsoa2011_cd, row_number() over(PARTITION BY ALF_PE ORDER BY START_DATE) AS rn
				FROM (
					SELECT ALF_PE, LSOA2011_CD,
						CASE WHEN turn11 BETWEEN START_DATE AND END_DATE THEN turn11 ELSE START_DATE END AS start_date,
						END_DATE
					FROM (
						SELECT *
						FROM (
							SELECT ad.ALF_PE, LSOA2011_CD,
								max(START_DATE, '2019-01-01') AS START_DATE, min(END_DATE, '2019-12-31') AS end_Date,
								add_years(wob, 11) AS turn11, add_years(wob, 25) AS turn25
							FROM SAIL1330V.WDSD_CLEAN_ADD_GEOG_CHAR_LSOA2011_20210704 ad
								LEFT JOIN SAIL1330V.WDSD_AR_PERS_20210704 age ON ad.ALF_PE = age.ALF_PE
							)
						WHERE '2019-01-01' <= END_DATE AND '2019-12-31' >= START_DATE
							AND turn11 <= end_date
						)		
					)
				)
			WHERE rn = 1 
			)lsoa ON alf = lsoa.ALF_PE
	UNION ALL
	----2020 cases----
	--get the first age and lsoa for each patient for this year
	SELECT *,
		2020 - year(wob) AS ageforyr
		--first_value(age) over(PARTITION BY ALF_PE ORDER BY START_DATE1) AS ageForYr
	FROM (
		--calculate age at start date
		--update end_date1 with death_dt
		SELECT *, 
			years_between(START_DATE1, wob) AS age,
			CASE WHEN death_dt BETWEEN START_DATE1 AND END_DATE1 THEN death_dt ELSE end_date1 END AS end_DATE2
		FROM (
			--limit to people who were between 11-24 during study period
			--update start_date and end_date to accommodate turning 11 or 25 midway through year
		SELECT cases.alf_pe AS alf, cases.gndr_cd, cases.wob, cases.turn11, cases.turn25, START_date, end_date,
				CASE WHEN cases.turn11 BETWEEN cases.START_DATE AND cases.END_DATE THEN cases.turn11 ELSE cases.start_date END AS START_DATE1,
				CASE WHEN cases.turn25-1 BETWEEN cases.START_DATE AND cases.END_DATE THEN cases.turn25-1 ELSE cases.end_date END AS end_DATE1,
				cases.death_dt
			FROM (
				--cut-off start/end dates to only cover this year
				SELECT addr.*, age.gndr_cd, age.wob, age.turn11, age.turn25, deaths.death_dt
				FROM (
					--select records with addresses in study period and join to demogs
					SELECT alf_pe, max(START_DATE, '2020-01-01') AS start_date, min(END_DATE, '2020-12-31') AS end_date
					FROM SAIL1330V.WDSD_CLEAN_ADD_WALES_20210704
					WHERE '2020-01-01' <= end_date AND '2020-12-31' >= START_DATE
						and welsh_address = 1
					) addr
				INNER JOIN (
					--select demogs and calc when they turn11 and turn25 (enter and leave the cohort)
					SELECT ALF_PE, gndr_cd, wob, add_years(wob, 11) AS turn11, add_years(wob, 25) AS turn25
					FROM SAIL1330V.WDSD_AR_PERS_20210704
					) age ON age.ALF_PE = addr.ALF_PE
				left JOIN (
					SELECT alf_pe, death_dt 
					FROM SAIL1330V.ADDE_DEATHS_20210628
					WHERE ALF_STS_CD  IN (1,4,39)
					) deaths ON deaths.alf_pe = addr.alf_pe
				) cases
			--only keep records where the time period of being 11-24 overlaps with the start/end dates of that address
			where turn11 <= end_date AND turn25 - 1 >= start_date	
		)
	) 
	INNER JOIN (
			--for each patient, number lsoa's in date order
			SELECT ALF_PE, LSOA2011_cd
			FROM (
				SELECT ALF_PE, lsoa2011_cd, row_number() over(PARTITION BY ALF_PE ORDER BY START_DATE) AS rn
				FROM (
					SELECT ALF_PE, LSOA2011_CD,
						CASE WHEN turn11 BETWEEN START_DATE AND END_DATE THEN turn11 ELSE START_DATE END AS start_date,
						END_DATE
					FROM (
						SELECT *
						FROM (
							SELECT ad.ALF_PE, LSOA2011_CD,
								max(START_DATE, '2020-01-01') AS START_DATE, min(END_DATE, '2020-12-31') AS end_Date,
								add_years(wob, 11) AS turn11, add_years(wob, 25) AS turn25
							FROM SAIL1330V.WDSD_CLEAN_ADD_GEOG_CHAR_LSOA2011_20210704 ad
								LEFT JOIN SAIL1330V.WDSD_AR_PERS_20210704 age ON ad.ALF_PE = age.ALF_PE
							)
						WHERE '2020-01-01' <= END_DATE AND '2020-12-31' >= START_DATE
							AND turn11 <= end_date
						)		
					)
				)
			WHERE rn = 1 
			)lsoa ON alf = lsoa.ALF_PE
) cohort LEFT JOIN SAILREFRV.WIMD2019_INDEX_AND_DOMAIN_RANKS_BY_SMALL_AREA wimd ON cohort.lsoa2011_cd = wimd.lsoa2011_cd
	LEFT JOIN SAILREFRV.RURAL_URBAN_CLASS_2011_OF_LLSOAREAS_IN_ENG_AND_WAL rural ON cohort.lsoa2011_cd = rural.LSOA11CD
WHERE GNDR_CD IN (1,2)


		

-------------------------------------------------------------------------------------------------
--CREATE WAST CASES TABLE

--4/10/2021 wastcases for all causes (all dispatch codes)		
DROP TABLE sailW1330v.df_wastcases_allcause

CREATE TABLE sailW1330v.df_wastcases_allcause (
	pcr int,
	incidentid_pe int,
	alf_pe int,
	incident_dttm timestamp,
	incident_end_dttm timestamp,
	incident_dt date,
	dt date,
	ageof_pat int,
	pat_sex int,
	dispatch_cd_andsuffix varchar(10),
	incidentstop_cd varchar(10),
	incidentstop_cd_desc varchar(60),
	pcr_code varchar(5)
	)

INSERT INTO sailW1330v.df_wastcases_allcause
SELECT cases.pcr, cases.incidentid_pe, cases.alf_pe, incident_dttm, incident_end_dttm, CAST(incident_dttm AS date) AS incident_dt,
		cases.dt ,cases.ageof_pat, pat_sex1, cases.DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc, pcr_code
FROM (
	SELECT pcr1 AS pcr, inc.incidentid_pe, alf_pe1 AS alf_pe, incident_dttm, 
		--average incident_dttm -> vehicle clear = 143 mins, so if vehicle clear is null, replace with 143 mins.
		CASE WHEN vehicleclear IS NULL THEN add_minutes(INCIDENT_DTTM, 143) ELSE VEHICLECLEAR END AS incident_end_dttm, 
		dt1 AS dt, inc.ageof_pat, inc.pat_sex AS pat_sex1,
		DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc, pcr_code
	FROM (
		SELECT *
		FROM SAIL1330V.WASD_AMBULANCECADINCIDENT_20210917
		WHERE incident_dttm BETWEEN '2016-01-01' AND '2020-12-31'
		) inc INNER JOIN (
			--logic to get incidentid_pe/alf_pe combo with highest posterior odds, while keeping incidents with multiple PCRs
			SELECT *
			FROM (
				--for each incidentid_pe/alf_pe combo, give number based on highest posteriorodds
				SELECT *, row_number() over(PARTITION BY INCIDENTID_PE, alf_pe1 ORDER BY posteriorodds DESC, pcr1) AS rn
				FROM (
					SELECT *
					FROM SAIL1330V.WASD_AMBULANCEPCRTOCADLINKS_20210917
					) l inner JOIN (
								SELECT *
								FROM (
									SELECT ROW_NUMBER() OVER(PARTITION BY pcr ORDER BY DT) AS rownum,
										alf_pe AS alf_pe1, pcr AS pcr1, dt AS dt1, tm AS tm1, con_main AS pcr_code
									FROM SAIL1330V.WASD_AMBULANCEPCR_20210917
									WHERE dt BETWEEN '2016-01-01' AND '2020-12-31'
										AND ALF_STS_CD IN ('1','4','39')
									)
								WHERE rownum = 1 
								) p ON l.pcr = p.pcr1
				)	
			--select rn = 1 to get the incidentid_pe/alf_pe combo with highest posterior odds
			WHERE rn = 1 
		) pcr_alf ON inc.incidentid_pe = pcr_alf.incidentid_pe	
		LEFT join (
			--add in vehicleclear date/time by linking vehicles table
			SELECT pcrno, i.INCIDENTID_PE, max(vehicleclear_dttm) AS vehicleclear
			FROM SAIL1330V.WASD_AMBULANCECADINCIDENT_20210917 i
				LEFT JOIN SAIL1330V.WASD_AMBULANCECADPATIENTREPORTFORMS_20210917 prf ON i.INCIDENTID_PE = prf.INCIDENTID_PE 
				LEFT JOIN SAIL1330V.WASD_AMBULANCECADVEHICLES_20210917 v ON v.vehicleid_pe = prf.VEHICLEID_PE
					AND v.INCIDENTID_PE = prf.incidentid_pe
					AND prf.VEHICLE_ALLOC_SEQ_NUM = v.VEHICLEALLOCATION_SEQ_NUM 
			GROUP BY pcrno, i.INCIDENTID_PE
			) end_dt ON pcr_alf.pcr1 = end_dt.pcrno AND pcr_alf.incidentid_pe = end_dt.incidentid_pe
		--inner join to cohort to only include patients in cohort
		INNER JOIN sailw1330v.DF_COHORT_LONG cohort ON ALF_PE1 = cohort.ALF_PE 
				AND date(incident_dttm) BETWEEN cohort.START_DATE1 AND cohort.END_DATE2
		--join demogs to calculate age to get 11-24 year olds
	) cases LEFT JOIN SAIL1330V.WDSD_AR_PERS_20210704 wds ON cases.alf_pe = wds.ALF_PE	
WHERE years_between(incident_dttm, wob) BETWEEN '11' AND '24'




------------------------------------------------------------------------------------------------------------------------

--	5/11/2021 wastcases for non_MH 		
DROP TABLE sailW1330v.df_wastcases_nonMH

CREATE TABLE sailW1330v.df_wastcases_nonMH (
	pcr int,
	incidentid_pe int,
	alf_pe int,
	incident_dttm timestamp,
	incident_end_dttm timestamp,
	incident_dt date,
	dt date,
	ageof_pat int,
	pat_sex int,
	dispatch_cd_andsuffix varchar(10),
	incidentstop_cd varchar(10),
	incidentstop_cd_desc varchar(60)
	)

INSERT INTO sailw1330v.df_wastcases_nonMH
	SELECT cases.pcr, cases.incidentid_pe, cases.alf_pe, incident_dttm, incident_end_dttm, CAST(incident_dttm AS date) AS incident_dt,
		cases.dt ,cases.ageof_pat, pat_sex1, cases.DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc
FROM (
	SELECT pcr1 AS pcr, inc.incidentid_pe, alf_pe1 AS alf_pe, incident_dttm, 
		--average incident_dttm -> vehicle clear = 143 mins, so if vehicle clear is null, replace with 143 mins.
		CASE WHEN vehicleclear IS NULL THEN add_minutes(INCIDENT_DTTM, 143) ELSE VEHICLECLEAR END AS incident_end_dttm, 
		dt1 AS dt, inc.ageof_pat, inc.pat_sex AS pat_sex1,
		DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc
	FROM (
		SELECT *
		FROM SAIL1330V.WASD_AMBULANCECADINCIDENT_20210917
		WHERE incident_dttm BETWEEN '2016-01-01' AND '2020-12-31'
			AND DISPATCH_CD_ANDSUFFIX NOT IN (
				SELECT ampds_cd
				FROM SAILW1330V.LB_AMPDS_MH_CODES)
		) inc INNER JOIN (
			--logic to get incidentid_pe/alf_pe combo with highest posterior odds, while keeping incidents with multiple PCRs
			SELECT *
			FROM (
				--for each incidentid_pe/alf_pe combo, give number based on highest posteriorodds
				SELECT *, row_number() over(PARTITION BY INCIDENTID_PE, alf_pe1 ORDER BY posteriorodds DESC, pcr1) AS rn
				FROM (
					SELECT *
					FROM SAIL1330V.WASD_AMBULANCEPCRTOCADLINKS_20210917
					) l inner JOIN (
								SELECT *
								FROM (
									SELECT ROW_NUMBER() OVER(PARTITION BY pcr ORDER BY DT) AS rownum,
										alf_pe AS alf_pe1, pcr AS pcr1, dt AS dt1, tm AS tm1
									FROM SAIL1330V.WASD_AMBULANCEPCR_20210917
									WHERE dt BETWEEN '2016-01-01' AND '2020-12-31'
										AND ALF_STS_CD IN ('1','4','39')
									)
								WHERE rownum = 1 
								) p ON l.pcr = p.pcr1
				)	
			--select rn = 1 to get the incidentid_pe/alf_pe combo with highest posterior odds
			WHERE rn = 1 
		) pcr_alf ON inc.incidentid_pe = pcr_alf.incidentid_pe	
		LEFT join (
			--add in vehicleclear date/time by linking vehicles table
			SELECT pcrno, i.INCIDENTID_PE, max(vehicleclear_dttm) AS vehicleclear
			FROM SAIL1330V.WASD_AMBULANCECADINCIDENT_20210917 i
				LEFT JOIN SAIL1330V.WASD_AMBULANCECADPATIENTREPORTFORMS_20210917 prf ON i.INCIDENTID_PE = prf.INCIDENTID_PE 
				LEFT JOIN SAIL1330V.WASD_AMBULANCECADVEHICLES_20210917 v ON v.vehicleid_pe = prf.VEHICLEID_PE
					AND v.INCIDENTID_PE = prf.incidentid_pe
					AND prf.VEHICLE_ALLOC_SEQ_NUM = v.VEHICLEALLOCATION_SEQ_NUM 
			GROUP BY pcrno, i.INCIDENTID_PE
			) end_dt ON pcr_alf.pcr1 = end_dt.pcrno AND pcr_alf.incidentid_pe = end_dt.incidentid_pe
		--inner join to cohort to only include patients in cohort
		INNER JOIN sailw1330v.DF_COHORT_LONG cohort ON ALF_PE1 = cohort.ALF_PE 
				AND date(incident_dttm) BETWEEN cohort.START_DATE1 AND cohort.END_DATE2
		--join demogs to calculate age to get 11-24 year olds
	) cases LEFT JOIN SAIL1330V.WDSD_AR_PERS_20210704 wds ON cases.alf_pe = wds.ALF_PE	
WHERE years_between(incident_dttm, wob) BETWEEN '11' AND '24'




--join WAST_MH_WK_RPT flag field to df_wastcases_nonMH table
DROP TABLE sailW1330v.df_wastcases_nonMH_a

CREATE TABLE sailW1330v.df_wastcases_nonMH_a (
	pcr int,
	incidentid_pe int,
	alf_pe int,
	incident_dttm timestamp,
	incident_end_dttm timestamp,
	incident_dt date,
	dt date,
	ageof_pat int,
	pat_sex int,
	dispatch_cd_andsuffix varchar(10),
	incidentstop_cd varchar(10),
	incidentstop_cd_desc varchar(60),
	wast_mh_week_rpt varchar(1)
	)


INSERT INTO sailW1330v.df_wastcases_nonMH_a
SELECT x.*
FROM (
	SELECT w.*, WAST_MH_WEEK_RPT 
	FROM SAILW1330V.DF_wastcases_nonMH w
		LEFT JOIN (
			SELECT '1' AS WAST_MH_WEEK_RPT, pcr1 AS pcr, inc.incidentid_pe, alf_pe1 AS alf_pe, incident_dttm, CAST(incident_dttm AS date) AS incident_dt, dt1 AS dt,
				inc.ageof_pat, inc.pat_sex AS pat_sex1, DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc
					FROM (
						SELECT *
						FROM SAIL1330V.WASD_AMBULANCECADINCIDENT_20210917
						WHERE incident_dttm BETWEEN '2016-01-01' AND '2021-01-31'
							AND DISPATCH_CD_ANDSUFFIX IN (
								SELECT ampds_cd
								FROM SAILW1330V.LB_AMPDS_MH_CODES)
						) inc INNER JOIN (
							--logic to get incidentid_pe/alf_pe combo with highest posterior odds, while keeping incidents with multiple PCRs
							SELECT *
							FROM (
								--for each incidentid_pe/alf_pe combo, give number based on highest posteriorodds
								SELECT *, row_number() over(PARTITION BY INCIDENTID_PE, alf_pe1 ORDER BY posteriorodds DESC, pcr1) AS rn
								FROM (
									SELECT *
									FROM SAIL1330V.WASD_AMBULANCEPCRTOCADLINKS_20210917
									) l inner JOIN (
												SELECT *
												FROM (
													SELECT ROW_NUMBER() OVER(PARTITION BY pcr ORDER BY DT) AS rownum,
														alf_pe AS alf_pe1, pcr AS pcr1, dt AS dt1, tm AS tm1
													FROM SAIL1330V.WASD_AMBULANCEPCR_20210917
													WHERE dt BETWEEN '2016-01-01' AND '2021-01-31'
														AND ALF_STS_CD IN ('1','4','39')
													)
												WHERE rownum = 1 
												) p ON l.pcr = p.pcr1
								)	
							--select rn = 1 to get the incidentid_pe/alf_pe combo with highest posterior odds
							WHERE rn = 1 
						) pcr_alf ON inc.incidentid_pe = pcr_alf.incidentid_pe
					) fu ON  w.ALF_PE = fu.alf_pe
							AND fu.incident_dttm > w.INCIDENT_DTTM AND fu.incident_dttm <= add_days(w.INCIDENT_DTTM, 7)						
	) x
GROUP BY WAST_MH_WEEK_RPT, pcr, incidentid_pe, alf_pe, incident_dttm, incident_end_dttm, incident_dt, dt,
				ageof_pat, pat_sex, DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc

				
DROP TABLE sailW1330v.df_wastcases_nonMH_b

CREATE TABLE sailW1330v.df_wastcases_nonMH_b (
	pcr int,
	incidentid_pe int,
	alf_pe int,
	incident_dttm timestamp,
	incident_end_dttm timestamp,
	incident_dt date,
	dt date,
	ageof_pat int,
	pat_sex int,
	dispatch_cd_andsuffix varchar(10),
	incidentstop_cd varchar(10),
	incidentstop_cd_desc varchar(60),
	wast_mh_week_rpt varchar(1),
	wast_mh_mth_rpt varchar(1)
	)


INSERT INTO sailW1330v.df_wastcases_nonMH_b
SELECT x.*
FROM (
	SELECT w.*, WAST_MH_MTH_RPT 
	FROM SAILW1330V.DF_wastcases_nonMH_a w
		LEFT JOIN (
			SELECT '1' AS WAST_MH_MTH_RPT, pcr1 AS pcr, inc.incidentid_pe, alf_pe1 AS alf_pe, incident_dttm, CAST(incident_dttm AS date) AS incident_dt, dt1 AS dt,
				inc.ageof_pat, inc.pat_sex AS pat_sex1, DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc
					FROM (
						SELECT *
						FROM SAIL1330V.WASD_AMBULANCECADINCIDENT_20210917
						WHERE incident_dttm BETWEEN '2016-01-01' AND '2021-01-31'
							AND DISPATCH_CD_ANDSUFFIX IN (
								SELECT ampds_cd
								FROM SAILW1330V.LB_AMPDS_MH_CODES)
						) inc INNER JOIN (
							--logic to get incidentid_pe/alf_pe combo with highest posterior odds, while keeping incidents with multiple PCRs
							SELECT *
							FROM (
								--for each incidentid_pe/alf_pe combo, give number based on highest posteriorodds
								SELECT *, row_number() over(PARTITION BY INCIDENTID_PE, alf_pe1 ORDER BY posteriorodds DESC, pcr1) AS rn
								FROM (
									SELECT *
									FROM SAIL1330V.WASD_AMBULANCEPCRTOCADLINKS_20210917
									) l inner JOIN (
												SELECT *
												FROM (
													SELECT ROW_NUMBER() OVER(PARTITION BY pcr ORDER BY DT) AS rownum,
														alf_pe AS alf_pe1, pcr AS pcr1, dt AS dt1, tm AS tm1
													FROM SAIL1330V.WASD_AMBULANCEPCR_20210917
													WHERE dt BETWEEN '2016-01-01' AND '2021-01-31'
														AND ALF_STS_CD IN ('1','4','39')
													)
												WHERE rownum = 1 
												) p ON l.pcr = p.pcr1
								)	
							--select rn = 1 to get the incidentid_pe/alf_pe combo with highest posterior odds
							WHERE rn = 1 
						) pcr_alf ON inc.incidentid_pe = pcr_alf.incidentid_pe
					) fu ON  w.ALF_PE = fu.alf_pe
							AND fu.incident_dttm > w.INCIDENT_DTTM AND fu.incident_dttm <= add_days(w.INCIDENT_DTTM, 30)						
	) x
GROUP BY WAST_MH_MTH_RPT, WAST_MH_WEEK_RPT, pcr, incidentid_pe, alf_pe, incident_dttm, incident_end_dttm, incident_dt, dt,
				ageof_pat, pat_sex, DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc
			

DROP TABLE sailW1330v.df_wastcases_nonMH_c

CREATE TABLE sailW1330v.df_wastcases_nonMH_c (
	pcr int,
	incidentid_pe int,
	alf_pe int,
	incident_dttm timestamp,
	incident_end_dttm timestamp,
	incident_dt date,
	dt date,
	ageof_pat int,
	pat_sex int,
	dispatch_cd_andsuffix varchar(10),
	incidentstop_cd varchar(10),
	incidentstop_cd_desc varchar(60),
	wast_mh_week_rpt varchar(1),
	wast_mh_mth_rpt varchar(1),
	wast_any_week_rpt varchar(1)
	)


INSERT INTO sailW1330v.df_wastcases_nonMH_c
SELECT x.*
FROM (
	SELECT w.*, WAST_ANY_WEEK_RPT
	FROM SAILW1330V.DF_wastcases_nonMH_b w
		LEFT JOIN (
			SELECT '1' AS WAST_ANY_WEEK_RPT, pcr1 AS pcr, inc.incidentid_pe, alf_pe1 AS alf_pe, incident_dttm, CAST(incident_dttm AS date) AS incident_dt, dt1 AS dt,
				inc.ageof_pat, inc.pat_sex AS pat_sex1, DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc
					FROM (
						SELECT *
						FROM SAIL1330V.WASD_AMBULANCECADINCIDENT_20210917
						WHERE incident_dttm BETWEEN '2016-01-01' AND '2021-01-31'
						) inc INNER JOIN (
							--logic to get incidentid_pe/alf_pe combo with highest posterior odds, while keeping incidents with multiple PCRs
							SELECT *
							FROM (
								--for each incidentid_pe/alf_pe combo, give number based on highest posteriorodds
								SELECT *, row_number() over(PARTITION BY INCIDENTID_PE, alf_pe1 ORDER BY posteriorodds DESC, pcr1) AS rn
								FROM (
									SELECT *
									FROM SAIL1330V.WASD_AMBULANCEPCRTOCADLINKS_20210917
									) l inner JOIN (
												SELECT *
												FROM (
													SELECT ROW_NUMBER() OVER(PARTITION BY pcr ORDER BY DT) AS rownum,
														alf_pe AS alf_pe1, pcr AS pcr1, dt AS dt1, tm AS tm1
													FROM SAIL1330V.WASD_AMBULANCEPCR_20210917
													WHERE dt BETWEEN '2016-01-01' AND '2021-01-31'
														AND ALF_STS_CD IN ('1','4','39')
													)
												WHERE rownum = 1 
												) p ON l.pcr = p.pcr1
								)	
							--select rn = 1 to get the incidentid_pe/alf_pe combo with highest posterior odds
							WHERE rn = 1 
						) pcr_alf ON inc.incidentid_pe = pcr_alf.incidentid_pe
					) fu ON  w.ALF_PE = fu.alf_pe
							AND fu.incident_dttm > w.INCIDENT_DTTM AND fu.incident_dttm <= add_days(w.INCIDENT_DTTM, 7)						
	) x
GROUP BY WAST_ANY_WEEK_RPT, WAST_MH_MTH_RPT, WAST_MH_WEEK_RPT, pcr, incidentid_pe, alf_pe, incident_dttm, incident_end_dttm, incident_dt, dt,
				ageof_pat, pat_sex, DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc

				
DROP TABLE sailW1330v.df_wastcases_nonMH_d

CREATE TABLE sailW1330v.df_wastcases_nonMH_d (
	pcr int,
	incidentid_pe int,
	alf_pe int,
	incident_dttm timestamp,
	incident_end_dttm timestamp,
	incident_dt date,
	dt date,
	ageof_pat int,
	pat_sex int,
	dispatch_cd_andsuffix varchar(10),
	incidentstop_cd varchar(10),
	incidentstop_cd_desc varchar(60),
	wast_mh_week_rpt varchar(1),
	wast_mh_mth_rpt varchar(1),
	wast_any_week_rpt varchar(1),
	wast_any_mth_rpt varchar(1)
	)


INSERT INTO sailW1330v.df_wastcases_nonMH_d
SELECT x.*
FROM (
	SELECT w.*, WAST_ANY_MTH_RPT 
	FROM SAILW1330V.DF_wastcases_nonMH_c w
		LEFT JOIN (
			SELECT '1' AS WAST_ANY_MTH_RPT, pcr1 AS pcr, inc.incidentid_pe, alf_pe1 AS alf_pe, incident_dttm, CAST(incident_dttm AS date) AS incident_dt, dt1 AS dt,
				inc.ageof_pat, inc.pat_sex AS pat_sex1, DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc
					FROM (
						SELECT *
						FROM SAIL1330V.WASD_AMBULANCECADINCIDENT_20210917
						WHERE incident_dttm BETWEEN '2016-01-01' AND '2021-01-31'
						) inc INNER JOIN (
							--logic to get incidentid_pe/alf_pe combo with highest posterior odds, while keeping incidents with multiple PCRs
							SELECT *
							FROM (
								--for each incidentid_pe/alf_pe combo, give number based on highest posteriorodds
								SELECT *, row_number() over(PARTITION BY INCIDENTID_PE, alf_pe1 ORDER BY posteriorodds DESC, pcr1) AS rn
								FROM (
									SELECT *
									FROM SAIL1330V.WASD_AMBULANCEPCRTOCADLINKS_20210917
									) l inner JOIN (
												SELECT *
												FROM (
													SELECT ROW_NUMBER() OVER(PARTITION BY pcr ORDER BY DT) AS rownum,
														alf_pe AS alf_pe1, pcr AS pcr1, dt AS dt1, tm AS tm1
													FROM SAIL1330V.WASD_AMBULANCEPCR_20210917
													WHERE dt BETWEEN '2016-01-01' AND '2021-01-31'
														AND ALF_STS_CD IN ('1','4','39')
													)
												WHERE rownum = 1 
												) p ON l.pcr = p.pcr1
								)	
							--select rn = 1 to get the incidentid_pe/alf_pe combo with highest posterior odds
							WHERE rn = 1 
						) pcr_alf ON inc.incidentid_pe = pcr_alf.incidentid_pe
					) fu ON  w.ALF_PE = fu.alf_pe
							AND fu.incident_dttm > w.INCIDENT_DTTM AND fu.incident_dttm <= add_days(w.INCIDENT_DTTM, 30)						
	) x
GROUP BY WAST_ANY_MTH_RPT, WAST_ANY_WEEK_RPT, WAST_MH_MTH_RPT, WAST_MH_WEEK_RPT, pcr, incidentid_pe, alf_pe, incident_dttm, 
	incident_end_dttm, incident_dt, dt,
				ageof_pat, pat_sex, DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc



-----------------------------------------------------------------------------------------------------------------------


--17/9/2021 UPDATED TO INCLUDE INCIDENT_END_DTTM FROM VEHICLE TABLE
--average difference between incident_dttm and vehicle clear = 143 minutes.
--Where vehicleclear is null, replace with incident_dttm + 143 minute			
DROP TABLE sailW1330v.df_wastcases

CREATE TABLE sailW1330v.df_wastcases (
	pcr int,
	incidentid_pe int,
	alf_pe int,
	incident_dttm timestamp,
	incident_end_dttm timestamp,
	incident_dt date,
	dt date,
	ageof_pat int,
	pat_sex int,
	dispatch_cd_andsuffix varchar(10),
	incidentstop_cd varchar(10),
	incidentstop_cd_desc varchar(60)
	)

INSERT INTO sailw1330v.df_wastcases
--WAST MH CASES: 9739 records
	SELECT cases.pcr, cases.incidentid_pe, cases.alf_pe, incident_dttm, incident_end_dttm, CAST(incident_dttm AS date) AS incident_dt,
		cases.dt ,cases.ageof_pat, pat_sex1, cases.DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc
FROM (
	SELECT pcr1 AS pcr, inc.incidentid_pe, alf_pe1 AS alf_pe, incident_dttm, 
		--average incident_dttm -> vehicle clear = 143 mins, so if vehicle clear is null, replace with 143 mins.
		CASE WHEN vehicleclear IS NULL THEN add_minutes(INCIDENT_DTTM, 143) ELSE VEHICLECLEAR END AS incident_end_dttm, 
		dt1 AS dt, inc.ageof_pat, inc.pat_sex AS pat_sex1,
		DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc
	FROM (
		--125458 rows (all unique incidentid_pe)
		SELECT *
		FROM SAIL1330V.WASD_AMBULANCECADINCIDENT_20210917
		WHERE incident_dttm BETWEEN '2016-01-01' AND '2020-12-31'
			AND DISPATCH_CD_ANDSUFFIX IN (
				SELECT ampds_cd
				FROM SAILW1330V.LB_AMPDS_MH_CODES)
		) inc INNER JOIN (
			--logic to get incidentid_pe/alf_pe combo with highest posterior odds, while keeping incidents with multiple PCRs
			SELECT *
			FROM (
				--for each incidentid_pe/alf_pe combo, give number based on highest posteriorodds
				SELECT *, row_number() over(PARTITION BY INCIDENTID_PE, alf_pe1 ORDER BY posteriorodds DESC, pcr1) AS rn
				FROM (
					SELECT *
					FROM SAIL1330V.WASD_AMBULANCEPCRTOCADLINKS_20210917
					) l inner JOIN (
								SELECT *
								FROM (
									SELECT ROW_NUMBER() OVER(PARTITION BY pcr ORDER BY DT) AS rownum,
										alf_pe AS alf_pe1, pcr AS pcr1, dt AS dt1, tm AS tm1
									FROM SAIL1330V.WASD_AMBULANCEPCR_20210917
									WHERE dt BETWEEN '2016-01-01' AND '2020-12-31'
										AND ALF_STS_CD IN ('1','4','39')
									)
								WHERE rownum = 1 
								) p ON l.pcr = p.pcr1
				)	
			--select rn = 1 to get the incidentid_pe/alf_pe combo with highest posterior odds
			WHERE rn = 1 
		) pcr_alf ON inc.incidentid_pe = pcr_alf.incidentid_pe	
		LEFT join (
			--add in vehicleclear date/time by linking vehicles table
			SELECT pcrno, i.INCIDENTID_PE, max(vehicleclear_dttm) AS vehicleclear
			FROM SAIL1330V.WASD_AMBULANCECADINCIDENT_20210917 i
				LEFT JOIN SAIL1330V.WASD_AMBULANCECADPATIENTREPORTFORMS_20210917 prf ON i.INCIDENTID_PE = prf.INCIDENTID_PE 
				LEFT JOIN SAIL1330V.WASD_AMBULANCECADVEHICLES_20210917 v ON v.vehicleid_pe = prf.VEHICLEID_PE
					AND v.INCIDENTID_PE = prf.incidentid_pe
					AND prf.VEHICLE_ALLOC_SEQ_NUM = v.VEHICLEALLOCATION_SEQ_NUM 
			GROUP BY pcrno, i.INCIDENTID_PE
			) end_dt ON pcr_alf.pcr1 = end_dt.pcrno AND pcr_alf.incidentid_pe = end_dt.incidentid_pe
		--inner join to cohort to only include patients in cohort
		INNER JOIN sailw1330v.DF_COHORT_LONG cohort ON ALF_PE1 = cohort.ALF_PE 
				AND date(incident_dttm) BETWEEN cohort.START_DATE1 AND cohort.END_DATE2
		--join demogs to calculate age to get 11-24 year olds
	) cases LEFT JOIN SAIL1330V.WDSD_AR_PERS_20210704 wds ON cases.alf_pe = wds.ALF_PE	
WHERE years_between(incident_dttm, wob) BETWEEN '11' AND '24'


	
--join WAST_MH_WK_RPT flag field to df_wastcases table
DROP TABLE sailW1330v.df_wastcases_a

CREATE TABLE sailW1330v.df_wastcases_a (
	pcr int,
	incidentid_pe int,
	alf_pe int,
	incident_dttm timestamp,
	incident_end_dttm timestamp,
	incident_dt date,
	dt date,
	ageof_pat int,
	pat_sex int,
	dispatch_cd_andsuffix varchar(10),
	incidentstop_cd varchar(10),
	incidentstop_cd_desc varchar(60),
	wast_mh_week_rpt varchar(1)
	)

INSERT INTO sailW1330v.df_wastcases_a
SELECT x.*
FROM (
	SELECT w.*, WAST_MH_WEEK_RPT 
	FROM SAILW1330V.DF_WASTCASES w
		LEFT JOIN (
			SELECT '1' AS WAST_MH_WEEK_RPT, pcr1 AS pcr, inc.incidentid_pe, alf_pe1 AS alf_pe, incident_dttm, CAST(incident_dttm AS date) AS incident_dt, dt1 AS dt,
				inc.ageof_pat, inc.pat_sex AS pat_sex1, DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc
					FROM (
						SELECT *
						FROM SAIL1330V.WASD_AMBULANCECADINCIDENT_20210917
						WHERE incident_dttm BETWEEN '2016-01-01' AND '2021-01-31'
							AND DISPATCH_CD_ANDSUFFIX IN (
								SELECT ampds_cd
								FROM SAILW1330V.LB_AMPDS_MH_CODES)
						) inc INNER JOIN (
							--logic to get incidentid_pe/alf_pe combo with highest posterior odds, while keeping incidents with multiple PCRs
							SELECT *
							FROM (
								--for each incidentid_pe/alf_pe combo, give number based on highest posteriorodds
								SELECT *, row_number() over(PARTITION BY INCIDENTID_PE, alf_pe1 ORDER BY posteriorodds DESC, pcr1) AS rn
								FROM (
									SELECT *
									FROM SAIL1330V.WASD_AMBULANCEPCRTOCADLINKS_20210917
									) l inner JOIN (
												SELECT *
												FROM (
													SELECT ROW_NUMBER() OVER(PARTITION BY pcr ORDER BY DT) AS rownum,
														alf_pe AS alf_pe1, pcr AS pcr1, dt AS dt1, tm AS tm1
													FROM SAIL1330V.WASD_AMBULANCEPCR_20210917
													WHERE dt BETWEEN '2016-01-01' AND '2021-01-31'
														AND ALF_STS_CD IN ('1','4','39')
													)
												WHERE rownum = 1 
												) p ON l.pcr = p.pcr1
								)	
							--select rn = 1 to get the incidentid_pe/alf_pe combo with highest posterior odds
							WHERE rn = 1 
						) pcr_alf ON inc.incidentid_pe = pcr_alf.incidentid_pe
					) fu ON  w.ALF_PE = fu.alf_pe
							AND fu.incident_dttm > w.INCIDENT_DTTM AND fu.incident_dttm <= add_days(w.INCIDENT_DTTM, 7)						
	) x
GROUP BY WAST_MH_WEEK_RPT, pcr, incidentid_pe, alf_pe, incident_dttm, incident_end_dttm, incident_dt, dt,
				ageof_pat, pat_sex, DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc

				
DROP TABLE sailW1330v.df_wastcases_b

CREATE TABLE sailW1330v.df_wastcases_b (
	pcr int,
	incidentid_pe int,
	alf_pe int,
	incident_dttm timestamp,
	incident_end_dttm timestamp,
	incident_dt date,
	dt date,
	ageof_pat int,
	pat_sex int,
	dispatch_cd_andsuffix varchar(10),
	incidentstop_cd varchar(10),
	incidentstop_cd_desc varchar(60),
	wast_mh_week_rpt varchar(1),
	wast_mh_mth_rpt varchar(1)
	)

INSERT INTO sailW1330v.df_wastcases_b
SELECT x.*
FROM (
	SELECT w.*, WAST_MH_MTH_RPT 
	FROM SAILW1330V.DF_WASTCASES_a w
		LEFT JOIN (
			SELECT '1' AS WAST_MH_MTH_RPT, pcr1 AS pcr, inc.incidentid_pe, alf_pe1 AS alf_pe, incident_dttm, CAST(incident_dttm AS date) AS incident_dt, dt1 AS dt,
				inc.ageof_pat, inc.pat_sex AS pat_sex1, DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc
					FROM (
						SELECT *
						FROM SAIL1330V.WASD_AMBULANCECADINCIDENT_20210917
						WHERE incident_dttm BETWEEN '2016-01-01' AND '2021-01-31'
							AND DISPATCH_CD_ANDSUFFIX IN (
								SELECT ampds_cd
								FROM SAILW1330V.LB_AMPDS_MH_CODES)
						) inc INNER JOIN (
							--logic to get incidentid_pe/alf_pe combo with highest posterior odds, while keeping incidents with multiple PCRs
							SELECT *
							FROM (
								--for each incidentid_pe/alf_pe combo, give number based on highest posteriorodds
								SELECT *, row_number() over(PARTITION BY INCIDENTID_PE, alf_pe1 ORDER BY posteriorodds DESC, pcr1) AS rn
								FROM (
									SELECT *
									FROM SAIL1330V.WASD_AMBULANCEPCRTOCADLINKS_20210917
									) l inner JOIN (
												SELECT *
												FROM (
													SELECT ROW_NUMBER() OVER(PARTITION BY pcr ORDER BY DT) AS rownum,
														alf_pe AS alf_pe1, pcr AS pcr1, dt AS dt1, tm AS tm1
													FROM SAIL1330V.WASD_AMBULANCEPCR_20210917
													WHERE dt BETWEEN '2016-01-01' AND '2021-01-31'
														AND ALF_STS_CD IN ('1','4','39')
													)
												WHERE rownum = 1 
												) p ON l.pcr = p.pcr1
								)	
							--select rn = 1 to get the incidentid_pe/alf_pe combo with highest posterior odds
							WHERE rn = 1 
						) pcr_alf ON inc.incidentid_pe = pcr_alf.incidentid_pe
					) fu ON  w.ALF_PE = fu.alf_pe
							AND fu.incident_dttm > w.INCIDENT_DTTM AND fu.incident_dttm <= add_days(w.INCIDENT_DTTM, 30)						
	) x
GROUP BY WAST_MH_MTH_RPT, WAST_MH_WEEK_RPT, pcr, incidentid_pe, alf_pe, incident_dttm, incident_end_dttm, incident_dt, dt,
				ageof_pat, pat_sex, DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc
			

DROP TABLE sailW1330v.df_wastcases_c

CREATE TABLE sailW1330v.df_wastcases_c (
	pcr int,
	incidentid_pe int,
	alf_pe int,
	incident_dttm timestamp,
	incident_end_dttm timestamp,
	incident_dt date,
	dt date,
	ageof_pat int,
	pat_sex int,
	dispatch_cd_andsuffix varchar(10),
	incidentstop_cd varchar(10),
	incidentstop_cd_desc varchar(60),
	wast_mh_week_rpt varchar(1),
	wast_mh_mth_rpt varchar(1),
	wast_any_week_rpt varchar(1)
	)

INSERT INTO sailW1330v.df_wastcases_c
SELECT x.*
FROM (
	SELECT w.*, WAST_ANY_WEEK_RPT
	FROM SAILW1330V.DF_WASTCASES_b w
		LEFT JOIN (
			SELECT '1' AS WAST_ANY_WEEK_RPT, pcr1 AS pcr, inc.incidentid_pe, alf_pe1 AS alf_pe, incident_dttm, CAST(incident_dttm AS date) AS incident_dt, dt1 AS dt,
				inc.ageof_pat, inc.pat_sex AS pat_sex1, DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc
					FROM (
						SELECT *
						FROM SAIL1330V.WASD_AMBULANCECADINCIDENT_20210917
						WHERE incident_dttm BETWEEN '2016-01-01' AND '2021-01-31'
						) inc INNER JOIN (
							--logic to get incidentid_pe/alf_pe combo with highest posterior odds, while keeping incidents with multiple PCRs
							SELECT *
							FROM (
								--for each incidentid_pe/alf_pe combo, give number based on highest posteriorodds
								SELECT *, row_number() over(PARTITION BY INCIDENTID_PE, alf_pe1 ORDER BY posteriorodds DESC, pcr1) AS rn
								FROM (
									SELECT *
									FROM SAIL1330V.WASD_AMBULANCEPCRTOCADLINKS_20210917
									) l inner JOIN (
												SELECT *
												FROM (
													SELECT ROW_NUMBER() OVER(PARTITION BY pcr ORDER BY DT) AS rownum,
														alf_pe AS alf_pe1, pcr AS pcr1, dt AS dt1, tm AS tm1
													FROM SAIL1330V.WASD_AMBULANCEPCR_20210917
													WHERE dt BETWEEN '2016-01-01' AND '2021-01-31'
														AND ALF_STS_CD IN ('1','4','39')
													)
												WHERE rownum = 1 
												) p ON l.pcr = p.pcr1
								)	
							--select rn = 1 to get the incidentid_pe/alf_pe combo with highest posterior odds
							WHERE rn = 1 
						) pcr_alf ON inc.incidentid_pe = pcr_alf.incidentid_pe
					) fu ON  w.ALF_PE = fu.alf_pe
							AND fu.incident_dttm > w.INCIDENT_DTTM AND fu.incident_dttm <= add_days(w.INCIDENT_DTTM, 7)						
	) x
GROUP BY WAST_ANY_WEEK_RPT, WAST_MH_MTH_RPT, WAST_MH_WEEK_RPT, pcr, incidentid_pe, alf_pe, incident_dttm, incident_end_dttm, incident_dt, dt,
				ageof_pat, pat_sex, DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc

				
DROP TABLE sailW1330v.df_wastcases_d

CREATE TABLE sailW1330v.df_wastcases_d (
	pcr int,
	incidentid_pe int,
	alf_pe int,
	incident_dttm timestamp,
	incident_end_dttm timestamp,
	incident_dt date,
	dt date,
	ageof_pat int,
	pat_sex int,
	dispatch_cd_andsuffix varchar(10),
	incidentstop_cd varchar(10),
	incidentstop_cd_desc varchar(60),
	wast_mh_week_rpt varchar(1),
	wast_mh_mth_rpt varchar(1),
	wast_any_week_rpt varchar(1),
	wast_any_mth_rpt varchar(1)
	)

INSERT INTO sailW1330v.df_wastcases_d
SELECT x.*
FROM (
	SELECT w.*, WAST_ANY_MTH_RPT 
	FROM SAILW1330V.DF_WASTCASES_c w
		LEFT JOIN (
			SELECT '1' AS WAST_ANY_MTH_RPT, pcr1 AS pcr, inc.incidentid_pe, alf_pe1 AS alf_pe, incident_dttm, CAST(incident_dttm AS date) AS incident_dt, dt1 AS dt,
				inc.ageof_pat, inc.pat_sex AS pat_sex1, DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc
					FROM (
						SELECT *
						FROM SAIL1330V.WASD_AMBULANCECADINCIDENT_20210917
						WHERE incident_dttm BETWEEN '2016-01-01' AND '2021-01-31'
						) inc INNER JOIN (
							--logic to get incidentid_pe/alf_pe combo with highest posterior odds, while keeping incidents with multiple PCRs
							SELECT *
							FROM (
								--for each incidentid_pe/alf_pe combo, give number based on highest posteriorodds
								SELECT *, row_number() over(PARTITION BY INCIDENTID_PE, alf_pe1 ORDER BY posteriorodds DESC, pcr1) AS rn
								FROM (
									SELECT *
									FROM SAIL1330V.WASD_AMBULANCEPCRTOCADLINKS_20210917
									) l inner JOIN (
												SELECT *
												FROM (
													SELECT ROW_NUMBER() OVER(PARTITION BY pcr ORDER BY DT) AS rownum,
														alf_pe AS alf_pe1, pcr AS pcr1, dt AS dt1, tm AS tm1
													FROM SAIL1330V.WASD_AMBULANCEPCR_20210917
													WHERE dt BETWEEN '2016-01-01' AND '2021-01-31'
														AND ALF_STS_CD IN ('1','4','39')
													)
												WHERE rownum = 1 
												) p ON l.pcr = p.pcr1
								)	
							--select rn = 1 to get the incidentid_pe/alf_pe combo with highest posterior odds
							WHERE rn = 1 
						) pcr_alf ON inc.incidentid_pe = pcr_alf.incidentid_pe
					) fu ON  w.ALF_PE = fu.alf_pe
							AND fu.incident_dttm > w.INCIDENT_DTTM AND fu.incident_dttm <= add_days(w.INCIDENT_DTTM, 30)						
	) x
GROUP BY WAST_ANY_MTH_RPT, WAST_ANY_WEEK_RPT, WAST_MH_MTH_RPT, WAST_MH_WEEK_RPT, pcr, incidentid_pe, alf_pe, incident_dttm, 
	incident_end_dttm, incident_dt, dt,
				ageof_pat, pat_sex, DISPATCH_CD_ANDSUFFIX, incidentstop_cd, incidentstop_cd_desc




-----------------------------------------------------------------------
--EDDS-  

--All MH-related events
--(Ambulance: arrival_mode = 1)
DROP TABLE SAILW1330V.DF_EDDS
						
CREATE TABLE sailw1330v.df_edds (
	alf_pe bigint,
	admin_arr_dt date,
	ADMIN_ARR_TM TIME,
	ADMIN_END_DT DATE,
	ADMIN_END_TM TIME,
	AGE INT,
	SEX VARCHAR(1),
	LSOA2011_CD VARCHAR(10),
	ARRIVAL_MODE VARCHAR(5),
	AMB_INCID_NO_PE VARCHAR(10),
	ATTEND_GROUP VARCHAR(3),
	DIAG_CD_1 VARCHAR(6),
	DIAG_CD_2 VARCHAR(6),
	DIAG_CD_3 VARCHAR(6),
	DIAG_CD_4 VARCHAR(6),
	DIAG_CD_5 VARCHAR(6),
	DIAG_CD_6 VARCHAR(6)
	)
	
INSERT INTO SAILW1330V.DF_EDDS
SELECT e.ALF_PE, ADMIN_ARR_DT, ADMIN_ARR_tm, ADMIN_END_DT, ADMIN_END_TM, age, sex, cohort.LSOA2011_CD, ARRIVAL_MODE, AMB_INCID_NO_PE, ATTEND_GROUP,
	DIAG_CD_1, DIAG_CD_2, DIAG_CD_3, DIAG_CD_4, DIAG_CD_5, DIAG_CD_6
FROM SAIL1330V.EDDS_EDDS_20211001 e
	INNER JOIN sailw1330v.DF_COHORT_LONG cohort ON e.ALF_PE = cohort.ALF_PE 
					AND e.admin_arr_dt BETWEEN cohort.START_DATE1 AND cohort.END_DATE2
WHERE YEAR(ADMIN_ARR_DT) BETWEEN '2016' AND '2020'
	AND age BETWEEN 11 AND 24
	AND ALF_STS_CD IN (1,4,39)
	AND (ATTEND_GROUP = '13' OR DIAG_CD_1 = '21Z' OR DIAG_CD_2 = '21Z' OR DIAG_CD_3 = '21Z'
	OR DIAG_CD_4 = '21Z' OR DIAG_CD_5 = '21Z' OR DIAG_CD_6 = '21Z')


	

----------------------------------------------------------------------------------------------------------
--WAST ED LINK

--lookup table for ED discharge codes
DROP TABLE sailw1330v.df_ed_discharge_lkp
	
CREATE TABLE sailw1330v.df_ed_discharge_lkp (
	dc_cd varchar(10),
	dc_desc varchar(20)
	)
	
INSERT INTO sailw1330v.df_ed_discharge_lkp (dc_cd, dc_desc)
VALUES 
 ('1', 'admitted TO hospital'), 
 ('01', 'admitted TO hospital'),
 ('2', 'admitted TO hospital'),
 ('02', 'admitted TO hospital'),
 ('3', 'admitted TO hospital'),
 ('03', 'admitted TO hospital'),
 ('4', 'dc clin approved'),
 ('04', 'dc clin approved'),
 ('5', 'dc clin approved'),
 ('05', 'dc clin approved'),
 ('6', 'dc clin approved'),
 ('06', 'dc clin approved'),
 ('7', 'dc clin approved'),
 ('07', 'dc clin approved'),
 ('8', 'dc clin approved'),
 ('08', 'dc clin approved'),
 ('9', 'self-discharge'),
 ('09', 'self-discharge'),
 ('10', 'died'),
 ('Unknown', 'Unknown')
 

 
DROP TABLE sailW1330v.df_wastcases_e
 
CREATE TABLE sailW1330v.df_wastcases_e (
	pcr int,
	incidentid_pe int,
	alf_pe int,
	incident_dttm timestamp,
	incident_end_dttm timestamp,
	incident_dt date,
	dt date,
	ageof_pat int,
	pat_sex int,
	dispatch_cd_andsuffix varchar(10),
	incidentstop_cd varchar(10),
	incidentstop_cd_desc varchar(60),
	wast_mh_week_rpt int,
	wast_mh_mth_rpt int,
	wast_any_week_rpt int,
	wast_any_mth_rpt int,
	dc_cd varchar(10),
	dc_desc varchar(20)
	)

INSERT INTO sailw1330v.DF_WASTCASES_e
SELECT t1.*, dc_desc
FROM (
	SELECT wast.*, 
		CASE WHEN discharge IS NOT NULL THEN DISCHARGE
			WHEN record_id_pe IS NOT NULL AND discharge IS NULL THEN 'Unknown' END AS discharge
	FROM sailw1330v.DF_WASTCASES_d wast
		LEFT JOIN(
			SELECT *
			FROM (
				--SELECT RECORD ID WITH HIGHEST POSTERIOR ODDS FOR THE 12 ALF WHO HAVE 2 DIFFERENT RECORD IDs LINKED TO THE SAME INCIDENT
				SELECT *, ROW_NUMBER() OVER(PARTITION BY INCIDENTID_PE, ALF_PE ORDER BY INCIDENTID_PE, ALF_PE, POSTERIORODDS DESC) AS ROWNUM
					FROM(
						SELECT * 
						FROM SAIL1330V.WASD_AMBULANCEEDTOCADLINKS_20210917 L
						LEFT JOIN SAIL1330V.EDDS_EDDS_20210902 E
						ON L.EMERGENCY_DEPT_ATTENDANCEID_PE = E.RECORD_ID_PE
						WHERE E.ALF_STS_CD IN(1,4,39)
						AND E.RECORD_ID_PE IS NOT NULL
						)
				) 
			WHERE ROWNUM = 1) E	ON Wast.INCIDENTID_PE = E.INCIDENTID_PE AND E.ALF_PE = Wast.ALF_PE
		) t1 LEFT JOIN sailw1330v.df_ed_discharge_lkp lkp ON t1.discharge = lkp.dc_cd






-----------------------------------------------------------------------------
--GP follow-up (any condition, 1-30 days)
--GP APPOINTMENTS ON SAME DAY AS WAST- WAST CAN BE BEFORE HOURS, IN HOURS, AFTER HOURS: -> look at 1-30 days and omit same day cases

DROP TABLE sailW1330v.df_wastcases_f
 
CREATE TABLE sailW1330v.df_wastcases_f (
	pcr int,
	incidentid_pe int,
	alf_pe int,
	incident_dttm timestamp,
	incident_end_dttm timestamp,
	incident_dt date,
	dt date,
	ageof_pat int,
	pat_sex int,
	dispatch_cd_andsuffix varchar(10),
	incidentstop_cd varchar(10),
	incidentstop_cd_desc varchar(60),
	wast_mh_week_rpt int,
	wast_mh_mth_rpt int,
	wast_any_week_rpt int,
	wast_any_mth_rpt int,
	dc_cd varchar(10),
	dc_desc varchar(20),
	gp_fu30any_dt date
	)

INSERT INTO sailW1330v.df_wastcases_f
SELECT wast.*, gp_fu30any_dt
FROM sailw1330v.df_wastcases_e wast
	LEFT JOIN (
			SELECT pcr, min(event_dt) AS gp_fu30any_dt
			FROM sailw1330v.df_wastcases_e w LEFT JOIN (
				SELECT alf_pe, event_dt
				FROM SAIL1330V.WLGP_GP_EVENT_CLEANSED_20210601
				WHERE alf_sts_cd IN ('1','4','39')
					AND event_dt >= '2016-01-01'
				) gp ON gp.alf_pe = w.alf_pe
					AND DAYS(event_dt) - DAYS(incident_dt) BETWEEN 1 AND 30
			GROUP BY pcr, incident_dttm
		) gp ON wast.pcr = gp.pcr 






----------------------------------------------------------------------------
--PEDW
--Get spells with: MH ICD code in 1st 3 diags of episode 1, psych cons_spec, emergency admission, and in cohort on admis_dt

DROP TABLE sailw1330v.df_pedw
	
CREATE TABLE sailw1330v.df_pedw (
	alf_pe int,
	spell_num_pe int,
	prov_unit_cd varchar(10),
	admis_dt date,
	disch_dt date,
	disch_mthd_cd varchar(10)
)

INSERT INTO  sailw1330v.df_pedw
SELECT s.ALF_PE, s.SPELL_NUM_PE, s.PROV_UNIT_CD, s.ADMIS_DT, DISCH_DT, DISCH_MTHD_CD
FROM SAIL1330V.PEDW_SPELL_20210704 s
	left JOIN (
		SELECT *
		FROM SAIL1330V.PEDW_EPISODE_20210704
		) e ON s.SPELL_NUM_PE = e.spell_num_pe AND s.PROV_UNIT_CD = e.prov_unit_cd
	left JOIN (
		--limit to 1st 3 diagnoses based on row_numbers from inner query, then group to get 1 row per spell_num/prov_unit
			SELECT spell_num_pe, prov_unit_cd, epi_num, min(diag_cd_123) AS dx
			FROM (
				--select relevant icd codes for 1st episode and give each diag_cd a row_number()
				SELECT *
				FROM SAIL1330V.PEDW_DIAG_20210704
				WHERE EPI_NUM = 1
					AND DIAG_NUM IN (1,2,3)
					AND (DIAG_CD_123 LIKE 'F%'
					OR (substring(DIAG_CD_123,1,1) = 'Y' AND (substring(DIAG_CD_123,2,2) BETWEEN 10 AND 34))
					OR (substring(DIAG_CD_123,1,1) = 'X' AND (substring(DIAG_CD_123,2,2) BETWEEN 60 AND 84)))
				)
			GROUP BY SPELL_NUM_PE, PROV_UNIT_CD, epi_num
		) d ON e.SPELL_NUM_PE = d.spell_num_pe AND e.PROV_UNIT_CD = d.prov_unit_cd AND e.epi_num = d.epi_num
	--inner join to limit to ALFs in cohort on the admis_dt
	INNER JOIN sailw1330v.DF_COHORT_LONG cohort ON s.ALF_PE = cohort.ALF_PE 
					AND s.admis_dt BETWEEN cohort.START_DATE1 AND cohort.END_DATE2 
WHERE s.ALF_STS_CD IN ('1','4','39')
	AND (con_spec_main_cd IN ('700','710','711','712','713','715') OR dx IS NOT null)
	--AND YEAR(admis_dt) BETWEEN 2016 AND 2020
	AND s.ADMIS_MTHD_CD IN ('21','22','23','24','25','27','28')
	

	


--------------------------------------------------------------------------------------------------------
--Combine all WAST, ED and PEDW cases into one table of presentations

DROP TABLE sailw1330v.df_presentations
	
--All MH-related events
CREATE TABLE sailw1330v.df_presentations (
	alf_pe bigint,
	startdate timestamp,
	enddate timestamp,
	service varchar(10)
	)
		
INSERT INTO sailw1330v.df_presentations
	--EDDS
	SELECT e.ALF_PE AS alf_pe, timestamp(ADMIN_ARR_DT, ADMIN_ARR_TM) AS startdate, timestamp(ADMIN_END_DT, ADMIN_END_TM) AS enddate,
		'ED' AS service
	FROM SAIL1330V.EDDS_EDDS_20211001 e
		INNER JOIN sailw1330v.DF_COHORT_LONG cohort ON e.ALF_PE = cohort.ALF_PE 
						AND e.admin_arr_dt BETWEEN cohort.START_DATE1 AND cohort.END_DATE2
	WHERE YEAR(ADMIN_ARR_DT) BETWEEN '2016' AND '2020'
		AND age BETWEEN 11 AND 24
		AND ALF_STS_CD IN (1,4,39)
		AND (ATTEND_GROUP = '13' OR DIAG_CD_1 = '21Z' OR DIAG_CD_2 = '21Z' OR DIAG_CD_3 = '21Z'
		OR DIAG_CD_4 = '21Z' OR DIAG_CD_5 = '21Z' OR DIAG_CD_6 = '21Z')
	UNION ALL
	--PEDW
	SELECT s.ALF_PE AS alf_pe, timestamp(s.ADMIS_DT, time('00.00.00')) AS startdate, timestamp(DISCH_DT, time('00.00.00')) AS enddate,
		'PEDW' AS service
	FROM SAIL1330V.PEDW_SPELL_20210704 s
		left JOIN (
			SELECT *
			FROM SAIL1330V.PEDW_EPISODE_20210704
			) e ON s.SPELL_NUM_PE = e.spell_num_pe AND s.PROV_UNIT_CD = e.prov_unit_cd
		left JOIN (
			--limit to 1st 3 diagnoses based on row_numbers from inner query, then group to get 1 row per spell_num/prov_unit
				SELECT spell_num_pe, prov_unit_cd, epi_num, min(diag_cd_123) AS dx
				FROM (
					--select relevant icd codes for 1st episode and give each diag_cd a row_number()
					SELECT *
					FROM SAIL1330V.PEDW_DIAG_20210704
					WHERE EPI_NUM = 1
						AND DIAG_NUM IN (1,2,3)
						AND (DIAG_CD_123 LIKE 'F%'
						OR (substring(DIAG_CD_123,1,1) = 'Y' AND (substring(DIAG_CD_123,2,2) BETWEEN 10 AND 34))
						OR (substring(DIAG_CD_123,1,1) = 'X' AND (substring(DIAG_CD_123,2,2) BETWEEN 60 AND 84)))
					)
				GROUP BY SPELL_NUM_PE, PROV_UNIT_CD, epi_num
			) d ON e.SPELL_NUM_PE = d.spell_num_pe AND e.PROV_UNIT_CD = d.prov_unit_cd AND e.epi_num = d.epi_num
		--inner join to limit to ALFs in cohort on the admis_dt
		INNER JOIN sailw1330v.DF_COHORT_LONG cohort ON s.ALF_PE = cohort.ALF_PE 
						AND s.admis_dt BETWEEN cohort.START_DATE1 AND cohort.END_DATE2 
	WHERE s.ALF_STS_CD IN ('1','4','39')
		AND (con_spec_main_cd IN ('700','710','711','712','713','715') OR dx IS NOT null)
		--AND YEAR(admis_dt) BETWEEN 2016 AND 2020
		AND s.ADMIS_MTHD_CD IN ('21','22','23','24','25','27','28')
	UNION ALL
	--WAST
	SELECT alf_pe, incident_dttm AS startdate, incident_end_dttm AS enddate,
		'WAST' AS service
	FROM sailW1330v.df_wastcases_f

	 
	


------------------------------------------------------------------------------

--merge presentations together if within 24 hours to get 'events'. 
	-- based on: bertwagner.com/posts/gaps-and-islands/

DROP TABLE sailw1330v.df_events1

CREATE TABLE sailw1330v.df_events1(
	alf_pe int,
	id int,
	startdate1 date,
	enddate1 date,
	first_service varchar(5),
	wastcases varchar(4),
	pedwcases varchar(4),
	edcases varchar(2)
	)
	
INSERT INTO sailw1330v.df_events1
	SELECT ALF_PE, id, min(STARTDATE ) AS startdate1, max(endDATE ) AS enddate1, first_service,
		sum(wastcase) AS wastcases,
		sum(pedwcase) AS pedwcases,
		sum(edcase) AS edcases
	FROM (
		SELECT *, FIRST_value(service) over(PARTITION BY ALF_PE, ID ORDER BY RN) AS FIRST_service,
			CASE WHEN service = 'WAST' THEN 1 ELSE 0 END AS wastcase,
			CASE WHEN service = 'PEDW' THEN 1 ELSE 0 END AS pedwcase,
			CASE WHEN service = 'ED' THEN 1 ELSE 0 END AS edcase
		FROM (
			SELECT *,
				CASE WHEN days_between(date(startdate), date(prevend)) > 1 THEN 1 ELSE 0 END AS newPeriod,
				sum(CASE WHEN  days_between(date(startdate), date(prevend)) > 1 THEN 1 ELSE 0 END) OVER (PARTITION BY ALF_PE ORDER BY RN) AS id
			from
				(
				SELECT ALF_PE, STARTDATE, ENDDATE, service,
					--order on date first so that end DATE is used before start TIME (which is guessed for PEDW).
					ROW_NUMBER() OVER (PARTITION BY ALF_PE ORDER BY ALF_PE, CAST(startdate AS date), CAST(enddate AS date), startdate, enddate) AS RN,
					lag(ENDDATE) over(PARTITION BY ALF_PE ORDER BY ALF_PE,  CAST(startdate AS date), CAST(enddate AS date), startdate, enddate) AS prevEnd
				FROM (		
					--select all presentations but update start/end times in PEDW records to 23.59.59
					SELECT ALF_PE, STARTDATE, enddate, service
					FROM sailw1330v.df_presentations
					WHERE service IN ('ED', 'WAST')
					UNION all
					SELECT ALF_PE, timestamp(CAST(STARTDATE AS date), CAST('23.59.59' AS time)) AS STARTDATE,
						timestamp(CAST(enddate AS date), CAST('23.59.59' AS time)) AS enddate, service
					FROM sailw1330v.df_presentations
					WHERE service = 'PEDW'
					)
				)
			ORDER BY ALF_PE , STARTDATE , ENDDATE
			)
		)
	GROUP BY ALF_PE, id, first_service
	ORDER BY ALF_PE , id
	


-----------------------------------------------------------------------------------------------------------


