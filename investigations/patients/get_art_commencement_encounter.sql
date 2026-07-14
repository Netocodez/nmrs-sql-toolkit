/*
===============================================================================
Name:
    Get ART Commencement Encounter

Category:
    Patient Investigation

Purpose:
    Retrieves the ART Commencement encounter (Encounter Type 25) for a
    specific patient.

Use Case:
    Used to verify:
    - ART commencement encounter ID
    - Encounter date and time
    - Visit ID
    - Date created
    - Void status

Parameters:
    patient_id

Example:
    patient_id = 15480

Output:
    Encounter details for Encounter Type 25.

Tables Used:
    encounter

===============================================================================
*/

SELECT
    encounter_id,
    encounter_datetime,
    CAST(encounter_datetime AS CHAR) AS raw_datetime_string,
    date_created,
    visit_id,
    voided
FROM encounter
WHERE patient_id = 15480
  AND encounter_type = 25;s