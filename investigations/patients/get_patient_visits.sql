/*
===============================================================================
Name:
    Get Patient Visits

Category:
    Patient Investigation

Purpose:
    Retrieves all visits associated with a patient.

Use Case:
    Used to review a patient's complete visit history, including:
    - Visit ID
    - Visit Type
    - Visit Start Date
    - Visit End Date
    - Facility Location
    - Void Status

Typical Workflow:
    • Verify all visits for a patient.
    • Identify the correct visit associated with an encounter.
    • Investigate missing or incorrect visit dates.
    • Obtain a visit_id for further investigation using
      get_visit_details.sql.

Parameter:
    patient_id

Example:
    patient_id = 12739

Tables Used:
    visit

===============================================================================
*/

SELECT
    visit_id,
    visit_type_id,
    date_started,
    CAST(date_started AS CHAR) AS raw_date_started,
    date_stopped,
    CAST(date_stopped AS CHAR) AS raw_date_stopped,
    location_id,
    voided
FROM visit
WHERE patient_id = 12739
ORDER BY date_started;