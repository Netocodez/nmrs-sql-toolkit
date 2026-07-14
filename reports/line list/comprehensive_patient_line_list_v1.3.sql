/*
===============================================================================
QUERY INFORMATION
===============================================================================

Name:
    Comprehensive Patient Line List

Category:
    Reports / Line Lists

Version:
    v1.3

Author:

Date Created:
    YYYY-MM-DD

Last Modified:
    YYYY-MM-DD

Database:
    NMRS (OpenMRS)
    MySQL 5.7+

Purpose:
    Generates a comprehensive ART patient line list containing demographics,
    ART history, pharmacy information, viral load, TPT, TB screening,
    OTZ enrollment, PBS status, and treatment outcomes.

Output:
    - Temporary table: full_line_list
    - Final SELECT containing the complete patient line list

===============================================================================
PARAMETERS
===============================================================================

Required Variables:

SET @endDate := 'YYYY-MM-DD';

Example:

SET @endDate := '2026-06-30';

===============================================================================
FEATURES
===============================================================================

✔ Patient Demographics
✔ ART Start Information
✔ Current ART Regimen
✔ Pharmacy Pickup History
✔ Viral Load History
✔ TPT/IPT Information
✔ TB Screening
✔ OTZ Information
✔ PBS Capture Status
✔ Treatment Outcomes
✔ Estimated Next Appointment
✔ Current ART Status

===============================================================================
TABLES USED
===============================================================================

patient
person
person_name
person_address
patient_identifier
encounter
obs
concept_name
patient_program
biometricinfo
biometricverificationinfo
global_property
location
address_hierarchy_entry

===============================================================================
DEPENDENCIES
===============================================================================

This script creates the following functions if they do not exist:

- getdatevalueobsid()
- getendofquarter()
- getmaxconceptobsid()
- getmaxconceptobsidwithformid()
- getcodedvalueobsid()
- getoutcome()
- getobsdatetime()

Temporary Objects Created:

- full_line_list
- IPT_list
- presumtive_tb_list
- OTZ_list
- final_line_list

===============================================================================
NOTES
===============================================================================

• Change ONLY @endDate before execution.
• Run against a reporting database whenever possible.
• Script is intended for read/reporting purposes.
• Tested on NMRS/OpenMRS.

===============================================================================
CHANGE LOG
===============================================================================

v1.3
- Current working version.
- Added PBS information.
- Added OTZ fields.
- Added enhanced TB/IPT indicators.
- Improved pharmacy outcome calculation.

===============================================================================
*/

-- VERSION 1.3
/*
                                         /$$                             /$$        /$$$$$$ 
                                        |__/                           /$$$$       /$$__  $$
 /$$    /$$ /$$$$$$   /$$$$$$   /$$$$$$$ /$$  /$$$$$$  /$$$$$$$       |_  $$      |__/  \ $$
|  $$  /$$//$$__  $$ /$$__  $$ /$$_____/| $$ /$$__  $$| $$__  $$        | $$         /$$$$$/
 \  $$/$$/| $$$$$$$$| $$  \__/|  $$$$$$ | $$| $$  \ $$| $$  \ $$        | $$        |___  $$
  \  $$$/ | $$_____/| $$       \____  $$| $$| $$  | $$| $$  | $$        | $$       /$$  \ $$
   \  $/  |  $$$$$$$| $$       /$$$$$$$/| $$|  $$$$$$/| $$  | $$       /$$$$$$ /$$|  $$$$$$/
    \_/    \_______/|__/      |_______/ |__/ \______/ |__/  |__/      |______/|__/ \______/ 
                                                                                        
  */    

SET @endDate := '2024-12-25'; -- only change the date in this line




SET @artStartDate :='';
SET @endTime :='23:59:59';
SET @endDate := CONCAT(@endDate, ' ', @endTime);
SET @lga :=    (SELECT global_property.property_value FROM global_property WHERE property = 'partner_reporting_lga_code');
DROP TABLE  IF EXISTS full_line_list;
DROP TABLE  IF EXISTS  IPT_list;
DROP TABLE  IF EXISTS  presumtive_tb_list;
DROP TABLE IF EXISTS OTZ_list;
DROP TEMPORARY TABLE IF EXISTS  final_line_list;

DELIMITER $$
DROP FUNCTION IF EXISTS `getdatevalueobsid`$$
CREATE FUNCTION `getdatevalueobsid`(`obsid` INT) RETURNS DATE
BEGIN
    DECLARE val DATE;
    SELECT  obs.value_datetime INTO val FROM obs WHERE  obs.obs_id=obsid;
	RETURN val;
END$$
DROP FUNCTION IF EXISTS `getendofquarter`$$
CREATE FUNCTION `getendofquarter`(`date_val` DATE) RETURNS DATE
BEGIN
	DECLARE fyear INT;
	DECLARE fquarter INT;
	DECLARE start_date DATE;
	DECLARE end_date DATE;
	DECLARE month_val INT;
	SET fyear=IF(QUARTER(date_val)=4,YEAR(date_val),YEAR(date_val));
	SET fquarter=IF(QUARTER(date_val)=4,MOD(QUARTER(date_val)+1,4),QUARTER(date_val)+1);
	SELECT CASE
	WHEN fquarter=1 THEN 12
	WHEN fquarter=2 THEN 3
	WHEN fquarter=3 THEN 6
	WHEN fquarter=4 THEN 9
	END INTO month_val;
	SELECT STR_TO_DATE(CONCAT(fyear,"-",month_val,"-",1),'%Y-%c-%e') INTO start_date;
	SELECT LAST_DAY(start_date) INTO end_date;
	RETURN end_date;
END $$
DROP FUNCTION IF EXISTS `getdatevalueobsid`$$
CREATE FUNCTION `getdatevalueobsid`(`obsid` INT) RETURNS DATE
BEGIN
    DECLARE val DATE;
    SELECT  obs.value_datetime INTO val FROM obs WHERE  obs.obs_id=obsid;
	RETURN val;
END$$
DROP FUNCTION IF EXISTS `getmaxconceptobsid`$$
CREATE  FUNCTION `getmaxconceptobsid`(`patientid` INT,`conceptid` INT, `cutoffdate` DATE) RETURNS DECIMAL(10,0)
BEGIN
    DECLARE value_num INT;
    SELECT  obs.obs_id INTO value_num FROM obs WHERE  obs.person_id=patientid AND obs.concept_id=conceptid AND obs.voided=0 AND
	obs.obs_datetime<=cutoffdate ORDER BY obs.obs_datetime DESC LIMIT 1;
	RETURN value_num;
END $$
DROP FUNCTION IF EXISTS `getmaxconceptobsidwithformid`$$
CREATE  FUNCTION `getmaxconceptobsidwithformid`(`patientid` INT,`conceptid` INT, `formid` INT,`cutoffdate` DATE) RETURNS DECIMAL(10,0)
BEGIN
    DECLARE value_num INT;
    SELECT  obs.obs_id INTO value_num FROM obs INNER JOIN encounter ON(encounter.encounter_id=obs.encounter_id AND encounter.voided=0) WHERE  encounter.form_id=formid AND obs.person_id=patientid
		AND obs.concept_id=conceptid AND obs.voided=0 AND obs.obs_datetime<=cutoffdate ORDER BY obs.obs_datetime DESC LIMIT 1;
	RETURN value_num;
END $$
DROP FUNCTION IF EXISTS `getcodedvalueobsid`$$
CREATE FUNCTION `getcodedvalueobsid`(`obsid` INT) RETURNS TEXT CHARSET utf8
BEGIN
    DECLARE val TEXT;
    SELECT  cn.name INTO val FROM
		obs
		INNER JOIN concept_name cn ON(obs.value_coded=cn.concept_id AND cn.locale='en' AND cn.locale_preferred=1) WHERE obs.obs_id=obsid;
	RETURN val;
END $$
DROP FUNCTION IF EXISTS `getoutcome`$$
CREATE FUNCTION `getoutcome`(`lastpickupdate` DATE,`daysofarvrefill` NUMERIC,`ltfudays` NUMERIC, `enddate` DATE) RETURNS TEXT CHARSET utf8
BEGIN
        DECLARE  ltfudate DATE;
        DECLARE  ltfunumber NUMERIC;
        DECLARE  daysdiff NUMERIC;
        DECLARE outcome TEXT;
        SET ltfunumber=daysofarvrefill+ltfudays;
        SELECT DATE_ADD(lastpickupdate, INTERVAL ltfunumber DAY) INTO ltfudate;
        SELECT DATEDIFF(ltfudate,enddate) INTO daysdiff;
        SELECT IF(daysdiff >=0,"Active","LTFU") INTO outcome;
        RETURN outcome;
END$$
DROP FUNCTION IF EXISTS `getobsdatetime`$$
CREATE FUNCTION `getobsdatetime`(`obsid` INT) RETURNS DATE
BEGIN
    DECLARE val DATE;
    SELECT  obs.obs_datetime INTO val FROM obs WHERE  obs.obs_id=obsid;
	RETURN val;
END$$
DELIMITER ;

CREATE TABLE full_line_list AS (
SELECT
"IHVN_GF-NTHRIP" AS "IP",
  (SELECT `state_province`  FROM  `location` WHERE `location_id` = 8 LIMIT 1) AS State,
   (SELECT `name`  FROM  `address_hierarchy_entry` WHERE `user_generated_id` = @lga  LIMIT 1 ) LGA,
   (SELECT global_property.property_value FROM global_property WHERE	property = 'Facility_Datim_Code' LIMIT 1) AS Datim_Code,
  (SELECT global_property.property_value FROM global_property WHERE property='Facility_Name' LIMIT 1) AS FacilityName,
  pid1.`patient_id` AS `patient_id`,
  pid1.identifier AS `PEPID`,
  pid2.identifier AS  `PatientHospitalNo`,
  pid1.uuid AS  `uuid`,
  person.gender AS `Sex`,
       -- Care Entry Point Update added =======
     CASE obt.concept_id IN (165839, 165966)
        WHEN obt.value_coded = 160529 THEN 'TB'
		WHEN obt.value_coded = 160546 THEN 'STI'
		WHEN obt.value_coded = 5271 THEN 'FP'
		WHEN obt.value_coded = 160542 THEN 'OPD'
		WHEN obt.value_coded = 161629 THEN 'Ward'
		WHEN obt.value_coded = 5622 THEN (SELECT ob.value_text FROM obs ob WHERE ob.concept_id= 165966 AND ob.encounter_id = obt.encounter_id LIMIT 1)     -- obt.value_text
		WHEN obt.value_coded = 165788 THEN 'Blood Bank'
		WHEN obt.value_coded = 160545 THEN 'Outreach'
		WHEN obt.value_coded = 165838 THEN 'Standalone HTS'
		WHEN obt.value_coded = 160539 THEN 'VCT'
		WHEN obt.value_coded = 165512 THEN 'PMTCT'
		ELSE NULL 
	END AS CareEntryPoint,  
  ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (166369)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND ob.`obs_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=14
     AND `value_coded` IN (160578,166285,166286,166287,162277)
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS `KPType`,
  ( SELECT
IF(TIMESTAMPDIFF(YEAR,person.birthdate,ob.value_datetime)>=5,@ageAtStart:=TIMESTAMPDIFF(YEAR,person.birthdate,ob.value_datetime),@ageAtStart:=0)
  FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (159599)
     AND ob.`value_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=25
     AND ob.voided=0
     AND e.voided=0
     LIMIT 1) AS `AgeAtStartofART`,
   ( SELECT
IF(
  TIMESTAMPDIFF(
    YEAR,
    person.birthdate,
    ob.value_datetime
  ) < 5,
  TIMESTAMPDIFF(
    MONTH,
    person.birthdate,
    ob.value_datetime
  ),
  NULL
)
  FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (159599)
     AND ob.`value_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=25
     AND ob.voided=0
     AND e.voided=0
     LIMIT 1) AS `AgeinMonths`,
DATE_FORMAT(@artStartDate := ( SELECT  DATE(`value_datetime`) FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (160554)
     AND ob.`value_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type = 14
     AND ob.voided=0
     AND e.voided=0
     LIMIT 1),'%d/%m/%Y') AS `DateConfirmedHIV+`,
DATE_FORMAT(@artStartDate := ( SELECT  DATE(`value_datetime`) FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (159599)
     AND ob.`value_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=25
     AND ob.voided=0
     AND e.voided=0
     LIMIT 1),'%d/%m/%Y') AS `ARTStartDate`,
     DATEDIFF(@endDate,@artStartDate) AS DaysOnART,
 MAX(IF(obs.concept_id=165708,DATE_FORMAT(@Pharmacy_LastPickupdate:=e2.encounter_datetime,'%d/%m/%Y'),NULL)) AS `Pharmacy_LastPickupdate`,

 DATE_FORMAT(getobsdatetime(getmaxconceptobsidwithformid(patient.patient_id,162240,27,getendofquarter(DATE_SUB(@endDate,INTERVAL 3 MONTH)))),'%d/%m/%Y') AS `Pharmacy_LastPickupdate_PreviousQuarter`,
MAX(@LastPickupDate := IF(obs.concept_id=159368,@daysOfRefil:=obs.value_numeric,NULL)) AS `DaysOfARVRefill`,
 MAX(IF(obs2.concept_id=165708,cn2.name,NULL)) AS `RegimenLineAtARTStart`,
MAX(
   IF(obs2.concept_id=164506,cn2.`name`,
   IF(obs2.concept_id=164513,cn2.`name`,
   IF(obs2.concept_id=164507,cn2.name,
   IF(obs2.concept_id=164514,cn2.name,
   IF(obs2.concept_id=165702,cn2.name,
   IF(obs2.concept_id=165703,cn2.name,NULL
   ))))))) AS `RegimenAtARTStart`,
MAX(IF(obs.concept_id=165708,cn1.name,NULL) ) AS `CurrentRegimenLine`,
( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (164506,164513,165702,164507,164514,165703)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND ob.`obs_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=13
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS `CurrentARTRegimen`,
     
     ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (166148)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND ob.`obs_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND value_coded IN (166276,166363)
     AND e.encounter_type=13
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS `DSD_Model`,
     
     ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (166276,166363)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND ob.`obs_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     -- AND value_coded IN (166276,166363)
     AND e.encounter_type=13
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS `DSD_Model_Type`,
     
MAX(IF(obs.concept_id=165050,cn1.name,NULL)) AS `CurrentPregnancyStatus`,
-- MAX(IF(obs.concept_id=856,obs.value_numeric,NULL)) AS `CurrentViralLoad`,
( SELECT  ob.value_numeric FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (856)
	 AND e.`encounter_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=11
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS `CurrentViralLoad`,
-- MAX(IF(obs.concept_id=856,DATE_FORMAT(obs.obs_datetime,'%d/%m/%Y'),NULL)) AS `DateofCurrentViralLoad`,
( SELECT  DATE_FORMAT(MAX(e.encounter_datetime),'%d/%m/%Y') FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (856)
	 AND e.`encounter_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=11
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS `DateofCurrentViralLoad`,
     ( SELECT  DATE_FORMAT(MAX(ob.value_datetime),'%d/%m/%Y') FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (165987)
     AND e.`encounter_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=11
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS `DateResultReceivedFacility`,
     ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (166422)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND e.`encounter_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=11
     AND ob.voided=0
     AND e.voided=0
     ORDER BY e.`encounter_datetime` DESC LIMIT 1) AS `Alphanumeric_Viral_Load_Result`,
      
  
  ( SELECT  DATE_FORMAT(obs.value_datetime,'%d-%b-%Y') FROM `obs`
     WHERE obs.person_id = patient.`patient_id`  
     AND obs.`concept_id` IN (159951) 
     AND obs.`obs_datetime` <= @endDate 
     AND obs.voided=0
     ORDER BY obs.obs_datetime DESC LIMIT 1) AS `LastDateOfSampleCollection`,
     
MAX(IF(obs.concept_id=164980,cn1.name,NULL) ) AS `ViralLoadIndication`,
CASE
WHEN MAX(IF(obs.concept_id=165470,cn1.name,IF(obs.concept_id=165708,IF(TIMESTAMPDIFF(DAY,sinner.last_date,@endDate)< @daysOfRefil + 29,"",""),NULL))) <> ''
THEN MAX(IF(obs.concept_id=165470,cn1.name,IF(obs.concept_id=165708,IF(TIMESTAMPDIFF(DAY,sinner.last_date,@endDate)< @daysOfRefil + 29,"",""),NULL)))
ELSE   MAX(IF(obs.`value_coded` =  159492, 'Transferred Out', NULL))  -- IF(e.`encounter_datetime` IS NULL, NULL,  'Transferred Out')
END AS `Outcomes`,
CASE
WHEN
( SELECT  DATE_FORMAT(ob.value_datetime,'%d/%m/%Y') FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` = 165469
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=15
     AND ob.voided=0
     AND e.voided=0
     LIMIT 1) <> ''
THEN
( SELECT  DATE_FORMAT(ob.value_datetime,'%d/%m/%Y') FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` = 165469
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=15
     AND ob.voided=0
     AND e.voided=0
     LIMIT 1)
ELSE    MAX(IF(obs.`value_coded` =  159492, IF(e.`encounter_datetime` IS NULL, NULL,DATE_FORMAT(e.`encounter_datetime`,'%d/%m/%Y')), NULL))      
END AS `Outcomes_Date`,
CASE
WHEN MAX(IF(obs.concept_id=165470,cn1.name,IF(obs.concept_id=165708,IF(TIMESTAMPDIFF(DAY,sinner.last_date,@endDate)< @daysOfRefil + 29,"",""),NULL))) <> ''
AND MAX(IF(obs.concept_id=165470,cn1.name,IF(obs.concept_id=165708,IF(TIMESTAMPDIFF(DAY,sinner.last_date,@endDate)< @daysOfRefil + 29,"",""),NULL))) = 'Death'
THEN ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (165889)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND e.`encounter_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=15
     AND ob.voided=0
     AND e.voided=0
     ORDER BY e.`encounter_datetime` DESC LIMIT 1)
END AS `Cause_of_Death`,
CASE
WHEN ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (166349)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     -- AND e.`encounter_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=15
     AND ob.voided=0
     AND e.voided=0
     ORDER BY e.`encounter_datetime` DESC LIMIT 1) <> '' AND (( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (166348)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     -- AND e.`encounter_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=15
     AND ob.voided=0
     AND e.voided=0
     ORDER BY e.`encounter_datetime` DESC LIMIT 1) <> '')
THEN ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (166348)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     -- AND e.`encounter_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=15
     AND ob.voided=0
     AND e.voided=0
     ORDER BY e.`encounter_datetime` DESC LIMIT 1)
     ELSE ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (166347)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     -- AND e.`encounter_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=15
     AND ob.voided=0
     AND e.voided=0
     ORDER BY e.`encounter_datetime` DESC LIMIT 1)
     END AS `VA_Cause_of_Death`,
DATE_ADD(MAX(IF(obs.concept_id=165708,DATE_FORMAT(e2.encounter_datetime,'%Y-%m-%d'),NULL)) ,INTERVAL (MAX(IF(obs.concept_id=159368,obs.value_numeric,NULL)) + 29) DAY) AS 'IIT_Date',
IF(DATE_ADD(MAX(IF(obs.concept_id=165708,DATE_FORMAT(e2.encounter_datetime,'%Y-%m-%d'),NULL)) ,INTERVAL (MAX(IF(obs.concept_id=159368,obs.value_numeric,NULL)) + 29) DAY) >= @endDate ,"Active","LTFU") AS `CurrentARTStatus_Pharmacy`,
'Transfer in with records' AS CurrentARTStatus,
IFNULL(getcodedvalueobsid(getmaxconceptobsidwithformid(patient.patient_id,165470,13,DATE_SUB(@endDate,INTERVAL 3 MONTH))),getoutcome(getobsdatetime(getmaxconceptobsidwithformid(patient.patient_id,162240,27,getendofquarter(DATE_SUB(@endDate,INTERVAL 3 MONTH)))),getconceptval(getmaxconceptobsidwithformid(patient.patient_id,162240,27,getendofquarter(DATE_SUB(@endDate,INTERVAL 3 MONTH))),159368,patient.patient_id),
29,IF(@endDate IS NULL OR @endDate = "", CURDATE(),getendofquarter(DATE_SUB(@endDate,INTERVAL 3 MONTH)))))  AS `ARTStatus_PreviousQuarter`,
DATE_FORMAT(person.birthdate,'%d/%m/%Y') AS `DOB`,
IF(TIMESTAMPDIFF(YEAR,person.birthdate,CURDATE())>=5,TIMESTAMPDIFF(YEAR,person.birthdate,CURDATE()),NULL) AS `Current_Age`,
IF(TIMESTAMPDIFF(YEAR,person.birthdate,CURDATE())<5,TIMESTAMPDIFF(MONTH,person.birthdate,CURDATE()),NULL) AS `CurrentAge_Months`,
CASE
WHEN
MAX(IF(obs.concept_id=160540,cn1.name, NULL)) = 'Transferred in'
OR MAX(IF(obs.concept_id=165242,cn1.name, NULL)) = 'Transfer in with records'
THEN "Yes"
ELSE "No"
END AS  `TransferredIn`,
CASE WHEN
MAX(IF(obs.concept_id=160540,cn1.name, NULL)) = 'Transfer in'
OR MAX(IF(obs.concept_id=165242,cn1.name, NULL)) = 'Transfer in with records'
THEN
( SELECT  DATE_FORMAT(ob.value_datetime,'%d/%m/%Y') FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` = 160534
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=14
     AND ob.voided=0
     AND e.voided=0
     LIMIT 1) END AS Date_Transfered_In,
pn.`family_name` AS Surname,
pn.`given_name` AS Firstname,
MAX(IF(sinner2.concept_id=1712,sinner2.concept_value,NULL)) AS `Educationallevel`,
MAX(IF(sinner2.concept_id=1054,sinner2.concept_value,NULL)) AS `MaritalStatus`,
MAX(IF(sinner2.concept_id=1542,sinner2.concept_value,NULL)) AS `JobStatus`,
part.`value` AS PhoneNo,
CASE WHEN
pa.`address2` IS NOT NULL
AND pa.`address2` <> ''
THEN pa.`address2`
ELSE pa.`address1`
END AS Address,
pa.`state_province` AS State_of_Residence,
pa.`city_village` AS LGA_of_Residence,
-- MAX(IF(sinner2.concept_id=5089,sinner2.value_numeric,NULL)) AS `LastWeight`,
( SELECT  ob.value_numeric FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (5089)
     AND ob.`obs_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=12
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS `Weight`,
-- MAX(IF(sinner2.concept_id=5089,DATE_FORMAT(DATE(sinner2.last_date),'%d/%m/%Y'),NULL)) AS `LastWeightDate`,
-- MAX(IF(sinner2.concept_id=5090,sinner2.value_numeric,NULL)) AS `LastHeight`,
( SELECT  ob.value_numeric FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (5090)
     AND ob.`obs_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=12
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS `Height`,
     -- MAX(IF(sinner2.concept_id=1342,sinner2.value_numeric,NULL)) AS `BMI`,
( SELECT  ob.value_numeric FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (1342)
     AND ob.`obs_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=12
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS `BMI`,
CONCAT(
MAX(IF(sinner2.concept_id=5085,sinner2.value_numeric,NULL)),
"/",
MAX(IF(sinner2.concept_id=5086,sinner2.value_numeric,NULL))
) AS 'BP',
MAX(IF(sinner2.concept_id=5356,sinner2.concept_value,NULL)) AS `Whostage`,
DATE_FORMAT(( SELECT  MIN(DATE(`obs_datetime`)) FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (164506,164507)
     AND ob.`obs_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=13
     AND `value_coded` IN (165681,165682,165691,165692)
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1),'%d/%m/%Y') AS `DateofFirstTLD_Pickup`,
(SELECT  ob.`value_numeric` FROM `obs` ob
	JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (5497)
     AND ob.`person_id` = patient.`patient_id`
     AND e.encounter_type=11
     AND ob.voided=0
     AND e.voided=0
     ORDER BY e.`encounter_datetime` DESC LIMIT 1) AS `CurrentCD4`,
     DATE((SELECT  e.`encounter_datetime` FROM `obs` ob
	JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (5497)
     AND ob.`person_id` = patient.`patient_id`
     AND e.encounter_type=11
     AND ob.voided=0
     AND e.voided=0
     ORDER BY e.`encounter_datetime` DESC LIMIT 1)) AS `CurrentCD4Date`,
     ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (167079)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND e.`encounter_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=11
     AND ob.voided=0
     AND e.voided=0
     ORDER BY e.`encounter_datetime` DESC LIMIT 1) AS 'AHD_Indication',
     
     ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (167088) AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND e.`encounter_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=11
     AND ob.voided=0
     AND e.voided=0
     ORDER BY e.`encounter_datetime` DESC LIMIT 1) AS 'Current_CD4_LFA_Result',
     
     ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (166697) AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND e.`encounter_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=11
     AND ob.voided=0
     AND e.voided=0
     ORDER BY e.`encounter_datetime` DESC LIMIT 1) AS 'Other_Test_(TB-LAM_LF-LAM_etc)',
     
     ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (167090) AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND e.`encounter_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=11
     AND ob.voided=0
     AND e.voided=0
     ORDER BY e.`encounter_datetime` DESC LIMIT 1) AS 'Serology_for_CrAg_Result',
     
     ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (167082) AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND e.`encounter_datetime` <= @endDate
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=11
     AND ob.voided=0
     AND e.voided=0
     ORDER BY e.`encounter_datetime` DESC LIMIT 1) AS 'CSF_for_CrAg_Result',
     
DATE_FORMAT(DATE_ADD(MAX(IF(obs.concept_id = 165708, sinner.last_date, NULL)), INTERVAL MAX(IF(obs.concept_id = 159368, obs.value_numeric, NULL)) DAY), '%d-%b-%Y') AS `EstimatedNextAppointmentPharmacy`,

MAX(IF(obs.concept_id=5096 AND enc.form_id=14 AND obs.voided =0,DATE_FORMAT(obs.value_datetime, '%d-%b-%Y'),NULL)) AS `Next_Ap_by_careCard`,

DATEDIFF(DATE_ADD(MAX(IF(obs.concept_id = 165708, sinner.last_date, NULL)), INTERVAL MAX(IF(obs.concept_id = 159368, obs.value_numeric, NULL)) DAY), NOW()) AS Days_To_Schedule,
ipt.IPT_Screening_Date  AS IPT_Screening_Date,
ipt.Are_you_coughing_currently  AS Are_you_coughing_currently,
ipt.Do_you_have_fever   AS Do_you_have_fever,
ipt.Are_you_losing_weight   AS Are_you_losing_weight,
ipt.Are_you_having_night_sweats   AS Are_you_having_night_sweats,
ipt.History_of_contacts_with_TB_patients   AS History_of_contacts_with_TB_patients,
ipt.Sputum_AFB  AS Sputum_AFB,
ipt.Sputum_AFB_Result AS Sputum_AFB_Result,
ipt.GeneXpert   AS GeneXpert,
ipt.GeneXpert_Result AS GeneXpert_Result,
ipt.Chest_Xray   AS Chest_Xray,
ipt.Chest_Xray_Result  AS Chest_Xray_Result,
ipt.Culture  AS Culture,
ipt.Culture_Result   AS Culture_Result,
ipt.Is_Patient_Eligible_For_IPT   AS Is_Patient_Eligible_For_IPT, 
MAX(IF(obs.concept_id=164852, DATE_FORMAT(obs.value_datetime,'%d-%b-%Y'),NULL)) AS `First_TPT_Pickupdate`,
MAX(IF(obs.concept_id=166096,DATE_FORMAT(obs.value_datetime,'%d-%b-%Y'),NULL)) AS `Last_TPT_Pickupdate`,
MAX(IF(obs.concept_id=165727 AND obs.value_coded= 1679,cn1.name,NULL)) AS `Current_TPT_Received`,
MAX(IF(obs.concept_id=166007, cn1.name, NULL)) AS `TPT_Outcomes`,
MAX(IF(obs.concept_id=166008, DATE_FORMAT(obs.value_datetime,'%d-%b-%Y'),NULL)) AS `Date_of_TPT_Outcome`,
MAX(IF(obs.concept_id=1659, cn1.name,NULL)) AS `Current_TB_Status`,
MAX(IF(obs.concept_id=1659, DATE_FORMAT(obs.obs_datetime,'%d-%b-%Y'),NULL)) AS `DateofCurrent_TBStatus`,
MAX(IF(obs.concept_id=1113, DATE_FORMAT(obs.obs_datetime,'%d-%b-%Y'),NULL)) AS `TB_Treatment_Start_Date`,
MAX(IF(obs.concept_id=159431, DATE_FORMAT(obs.obs_datetime,'%d-%b-%Y'),NULL))  AS `TB_Treatment_Stop_Date`,
DATE_FORMAT(pprg.date_enrolled,'%d/%m/%Y') AS Date_Enrolled_Into_OTZ,
MAX(IF(obs.concept_id=166350, DATE_FORMAT(obs.value_datetime,'%d-%b-%Y'),NULL)) AS `Date_Enrolled_Into_OTZ_Plus`,
MAX(IF(otz.concept_id=166256,otz.name,NULL) ) AS Positive_living,
MAX(IF(otz.concept_id=166257,otz.name,NULL) ) AS Treatment_Literacy,
MAX(IF(otz.concept_id=166258,otz.name,NULL) ) AS Adolescents_participation,
MAX(IF(otz.concept_id=166259,otz.name,NULL) ) AS Leadership_training,
MAX(IF(otz.concept_id=166260,otz.name,NULL)) AS Peer_To_Peer_Mentoship,
MAX(IF(otz.concept_id=166255,otz.name,NULL))  AS Role_of_OTZ,
MAX(IF(otz.concept_id=166267,otz.name,NULL)) AS OTZ_Champion_Oreintation,
MAX(IF(otz.concept_id=166272,otz.name,NULL))  AS Transitioned_Adult_Clinic,
MAX(IF(otz.concept_id=166275,otz.name,NULL) )  AS OTZ_Outcome,
MAX(IF(otz.concept_id=166275,DATE_FORMAT(otz.value_datetime,'%d/%m/%Y'),NULL) )  AS OTZ_Outcome_Date,
IF(b.`patient_Id` IS NOT NULL, "Yes", "No" ) AS "PBS_Capturee",
DATE_FORMAT(b.`date_created`,'%d/%m/%Y') AS 'PBS_Capture_Date',
CONCAT(DATE(@endDate), "_v1.2") AS 'Date_Generated'
  FROM patient
  LEFT JOIN patient_identifier pid1 ON(pid1.patient_id=patient.patient_id AND patient.voided=0 AND pid1.identifier_type=4)
  LEFT JOIN patient_identifier pid2 ON(pid2.patient_id=patient.patient_id AND patient.voided=0 AND pid2.identifier_type=5)
  LEFT JOIN `person_name` pn ON(pn.`person_id`=patient.patient_id AND patient.voided=0 AND pn.`preferred`=1)
  LEFT JOIN `person_address` pa ON(pa.`person_id`=patient.patient_id AND patient.voided=0 AND pa.`preferred`=1)
  LEFT JOIN `person_attribute` part ON(part.`person_id`=patient.patient_id AND patient.voided=0 AND part.voided=0 AND part.`person_attribute_type_id`=8)
  LEFT JOIN (SELECT obs.person_id, obs.concept_id, obs.value_coded, obs.value_text, obs.encounter_id FROM obs WHERE concept_id = 165839 AND obs.voided = 0) AS obt ON(obt.person_id=patient.patient_id AND patient.voided =0)

  INNER JOIN
  (SELECT
obs.person_id,
obs.concept_id,
 MAX(obs.obs_datetime) AS last_date,
MIN(obs.obs_datetime) AS first_date
FROM obs WHERE obs.voided=0 AND obs.obs_datetime<=@endDate AND concept_id IN(159599,165708,159368,164506,164513,164507,164514,165702,165703,165050,
856,164980,165470,160540,165242,165469,166043,164505,1652,161364,630,103166, 1659,1113,159431, 164852, 166096, 165727, 5096, 165708, 159368) 
GROUP BY obs.person_id,obs.concept_id ) AS sinner
ON (sinner.person_id=patient.patient_id AND patient.voided=0)

INNER JOIN obs ON(obs.person_id=patient.patient_id AND obs.concept_id=sinner.concept_id AND obs.obs_datetime=sinner.last_date 
AND obs.voided=0 AND obs.obs_datetime<=@endDate)


INNER JOIN obs obs2 ON(obs2.person_id=patient.patient_id AND obs2.concept_id=sinner.concept_id AND obs2.obs_datetime=sinner.first_date AND obs2.voided=0 )


INNER JOIN encounter ON(encounter.patient_id=patient.patient_id AND encounter.form_id=23 AND encounter.voided=0)
LEFT JOIN encounter e ON(e.patient_id=patient.patient_id AND e.form_id=30 AND e.voided=0)
LEFT JOIN encounter enc ON(enc.encounter_id=obs.encounter_id AND enc.voided=0 AND obs.voided=0 )


LEFT JOIN (SELECT  DISTINCT `patient_Id`,`date_created` FROM `biometricinfo` GROUP BY `patient_Id`) AS b ON (patient.patient_id = b.patient_id)


LEFT JOIN
  (SELECT
obs.person_id,
obs.value_numeric,
obs.concept_id,
(SELECT `name` FROM concept_name WHERE (concept_name.`concept_id` = `obs`.`value_coded` AND `locale` = 'en' AND `locale_preferred` =1) LIMIT 1) AS concept_value,
MAX(obs.obs_datetime) AS last_date
FROM obs WHERE obs.voided=0 AND obs.obs_datetime<=@endDate AND concept_id IN(5356,5089,5085,5086, 1542, 1054, 1712) GROUP BY obs.person_id,obs.concept_id ) AS sinner2
ON (sinner2.person_id=patient.patient_id )

INNER JOIN person ON(person.person_id=patient.patient_id)
LEFT JOIN concept_name cn1 ON(obs.value_coded=cn1.concept_id AND cn1.locale='en' AND cn1.locale_preferred=1)
LEFT JOIN concept_name cn2 ON(obs2.value_coded=cn2.concept_id AND cn2.locale='en' AND cn2.locale_preferred=1)
LEFT JOIN
(SELECT patient_id,form_id,encounter_type,voided,MAX(encounter_datetime) AS encounter_datetime FROM encounter WHERE form_id=27 AND encounter_type=13 AND voided=0
 AND DATE(`encounter_datetime`) <= @endDate  GROUP BY patient_id) e2 ON(e2.patient_id=patient.patient_id)
 
 
 LEFT JOIN (
SELECT
obs.person_id,
obs.concept_id,
cn2.`name`,
obs.value_coded,
obs.`value_datetime`,
MIN(obs.obs_datetime) AS last_date
FROM obs 
LEFT JOIN concept_name cn2 ON(obs.value_coded=cn2.concept_id AND cn2.locale='en' AND cn2.locale_preferred=1)
WHERE obs.voided=0 AND obs.obs_datetime<=@endDate AND obs.concept_id IN(166256, 166257, 166258, 166259, 166260, 166255, 166267,166272,166275,166008, 166275)
GROUP BY obs.person_id,obs.concept_id 
) AS  otz ON (otz.person_id=patient.patient_id )

LEFT JOIN patient_program pprg ON(pprg.patient_id=patient.patient_id AND pprg.program_id=5 AND pprg.voided=0)

LEFT JOIN (
SELECT
pid1.patient_id,
pid1.identifier AS `PepID`,
( SELECT  DATE_FORMAT(MAX(e.encounter_datetime),'%d/%m/%Y') FROM  encounter e
     WHERE e.`encounter_datetime` <= @endDate
     AND e.`patient_id` =  patient.`patient_id`
     AND e.encounter_type=23
     AND e.voided=0
     ORDER BY e.`encounter_datetime` DESC LIMIT 1) AS `IPT_Screening_Date`,
   ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (143264)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=23
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS "Are_you_coughing_currently",
     ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (140238)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=23
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS "Do_you_have_fever",
     ( SELECT  CASE
   WHEN ob.value_coded = 2 THEN "No"
   WHEN ob.value_coded = 1 THEN "Yes"
   ELSE ''
   END
   FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (832)
     AND ob.`person_id` =  patient.`patient_id`
     AND (e.encounter_type=23)
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS "Are_you_losing_weight",
     ( SELECT  CASE
   WHEN ob.value_coded = 2 THEN "No"
   WHEN ob.value_coded = 1 THEN "Yes"
   ELSE ''
   END
   FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (133027)
     AND ob.`person_id` =  patient.`patient_id`
     AND (e.encounter_type=23)
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS "Are_you_having_night_sweats",
     ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (165967)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=23
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS "History_of_contacts_with_TB_patients",
( SELECT  CASE
   WHEN ob.value_coded = 1 THEN "Yes"
   ELSE ''
   END
   FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (166141)
     AND ob.`person_id` =  patient.`patient_id`
     AND (e.encounter_type=23)
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS "Sputum_AFB",
      ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (165968)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=23
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS  "Sputum_AFB_Result",
     ( SELECT  CASE
   WHEN ob.value_coded = 1 THEN "Yes"
   ELSE ''
   END
   FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (166142)
     AND ob.`person_id` =  patient.`patient_id`
     AND (e.encounter_type=23)
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS "GeneXpert",
      ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (165975)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=23
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS  "GeneXpert_Result",
     ( SELECT  CASE
   WHEN ob.value_coded = 1 THEN "Yes"
   ELSE ''
   END
   FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (166143)
     AND ob.`person_id` =  patient.`patient_id`
     AND (e.encounter_type=23)
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS "Chest_Xray",
      ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (165972)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=23
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS  "Chest_Xray_Result",
     ( SELECT  CASE
   WHEN ob.value_coded = 1 THEN "Yes"
   ELSE ''
   END
   FROM `obs` ob JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (166144)
     AND ob.`person_id` =  patient.`patient_id`
     AND (e.encounter_type=23)
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS "Culture",
      ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (165969)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=23
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS  "Culture_Result",
     ( SELECT  cn.`name` FROM `obs` ob  JOIN `concept_name` cn ON cn.`concept_id` = ob.value_coded JOIN encounter e ON ob.encounter_id=e.encounter_id
     WHERE ob.`concept_id` IN (165986)  AND cn.`locale` = 'en' AND cn.`locale_preferred` = 1
     AND ob.`person_id` =  patient.`patient_id`
     AND e.encounter_type=23
     AND ob.voided=0
     AND e.voided=0
     ORDER BY ob.obs_datetime DESC LIMIT 1) AS `Is_Patient_Eligible_For_IPT`
  FROM patient
  INNER JOIN patient_identifier pid1 ON(pid1.patient_id=patient.patient_id AND patient.voided=0 AND pid1.identifier_type=4)
WHERE patient.voided=0 GROUP BY patient.patient_id,pid1.identifier
) AS ipt ON  (ipt. patient_id = patient.patient_id)



WHERE patient.voided=0 AND obs.concept_id IN(159599,165708,159368,164506,164513,164507,164514,165702,165703,165050,856,164980,165470,160540,165242, 
164852,166096,165727,1659,1113,159431,5096, 165708, 159368) AND 
obs2.concept_id IN(159599,165708,159368,164506,164513,164507,164514,165702,165703,165050,856,164980,165470,160540,165242, 164852,166096,165727,1659,1113,159431, 5096,
165708, 159368) GROUP BY patient.patient_id,pid1.identifier);




UPDATE full_line_list SET 
CurrentARTStatus = IF(outcomes IS NULL,  CurrentARTStatus_Pharmacy, outcomes),
EstimatedNextAppointmentPharmacy = DATE_ADD( STR_TO_DATE(Pharmacy_LastPickupdate,'%d/%m/%Y'), INTERVAL DaysOfARVRefill DAY);



SELECT full_line_list.*, 
CONCAT(full_line_list.`Datim_Code` ,"_" ,full_line_list.`PepID`) AS 'Unique_Id',
IF(info.date_created IS NOT NULL , "Yes", "") AS "PBS_Recapture" ,
DATE(info.date_created) AS 'PBS_Recapture_Date',
info.recapture_count AS "PBS_Recapture_Count"
FROM full_line_list
LEFT JOIN   (
SELECT
`patient_Id`, MAX(`date_created`) AS date_created , `recapture_count`
FROM  `biometricverificationinfo` GROUP BY `patient_Id`) AS info
ON info.patient_Id = full_line_list.patient_Id;