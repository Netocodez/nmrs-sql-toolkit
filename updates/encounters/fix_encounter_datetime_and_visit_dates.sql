/*
===============================================================================
Name:
    Fix Encounter DateTime and Visit Dates

Category:
    Data Update / Encounter Correction

Purpose:
    Corrects an invalid encounter datetime and updates the associated visit's
    start and stop dates to ensure the encounter falls within the visit period.

Use Case:
    Use when:
    - An encounter has an incorrect or corrupted datetime.
    - A visit has incorrect start or stop dates.
    - Encounter datetime falls outside the visit boundaries.
    - NDR validation or NMRS reports fail due to invalid visit dates.

Typical Workflow:

    Step 1:
        Run investigations/patient/get_patient_visits.sql
        ↓
        Identify the correct visit_id

    Step 2:
        Run investigations/patient/get_visit_encounters.sql
        ↓
        Verify the encounter datetime(s)

    Step 3:
        Run investigations/patient/get_visit_details.sql
        ↓
        Verify the current visit start and stop dates

    Step 4:
        Execute this update script

    Step 5:
        Re-run the investigation queries to confirm the correction

Parameters:

    visit_id
    corrected_encounter_datetime
    corrected_visit_start
    corrected_visit_end

Example:

    visit_id = 196629
    corrected date = 2015-06-24

Tables Updated:

    encounter
    visit

WARNING:

⚠ This script modifies production data.
⚠ Always back up the affected records before updating.
⚠ Verify the visit_id before execution.
⚠ Revalidate the patient record after making changes.

===============================================================================
*/

-- ============================================================================
-- Step 1: Update the encounter datetime
-- ============================================================================

UPDATE encounter
SET encounter_datetime = '2015-06-24 00:00:00'
WHERE visit_id = 196629
  AND encounter_datetime = '1019-10-30 00:00:00';

-- ============================================================================
-- Step 2: Update the visit boundaries
-- ============================================================================

UPDATE visit
SET date_started = '2015-06-24 00:00:00',
    date_stopped = '2015-06-24 23:59:59'
WHERE visit_id = 196629;