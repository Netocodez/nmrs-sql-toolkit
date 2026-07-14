/*
===============================================================================
Name:
    Get Visit Details

Category:
    Patient Investigation

Purpose:
    Retrieves the start and stop dates for a specific visit.

Use Case:
    After obtaining a patient's encounter (e.g., ART Commencement Encounter),
    use the associated visit_id to verify:
    - Visit start date
    - Visit end date
    - Visit type
    - Void status

Typical Workflow:
    Step 1:
        Run get_art_commencement_encounter.sql
        ↓
        Obtain the visit_id

    Step 2:
        Run this query using the visit_id
        ↓
        Verify the visit start and stop dates

Parameter:
    visit_id

Example:
    visit_id = 247261

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
    voided
FROM visit
WHERE visit_id = 247261;