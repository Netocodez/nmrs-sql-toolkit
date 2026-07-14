/*
===============================================================================
Name:
    Get Visit Encounters

Category:
    Patient Investigation

Purpose:
    Retrieves all encounter date/times associated with a specific visit.

Use Case:
    Used to:
    - Verify the encounters recorded within a visit.
    - Check encounter chronology.
    - Confirm that encounter dates align with the visit start and stop dates.
    - Investigate visit-related data inconsistencies.

Typical Workflow:
    Step 1:
        Run get_patient_visits.sql
        ↓
        Identify the required visit_id

    Step 2:
        Run this query using the visit_id
        ↓
        Review all encounters linked to the visit

    Step 3:
        If necessary, compare the encounter dates with
        get_visit_details.sql.

Parameter:
    visit_id

Example:
    visit_id = 196629

Tables Used:
    encounter

===============================================================================
*/

SELECT
    encounter_id,
    encounter_type,
    encounter_datetime,
    CAST(encounter_datetime AS CHAR) AS raw_encounter_datetime,
    form_id,
    provider_id,
    location_id,
    voided
FROM encounter
WHERE visit_id = 196629
ORDER BY encounter_datetime;