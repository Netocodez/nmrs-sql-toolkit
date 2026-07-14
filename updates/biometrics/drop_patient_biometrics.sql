/*
===============================================================================
Name:
    Drop Patient Biometrics

Category:
    Data Update / Biometrics

Purpose:
    Removes all biometric enrollment (capture) and verification (recapture)
    records for a patient, allowing the patient to undergo a fresh biometric
    enrollment.

Use Case:
    • Corrupted biometric templates
    • Failed biometric synchronization
    • Duplicate biometric records
    • Biometric recapture issues
    • PBS troubleshooting

Parameters:
    patient_Id

Example:
    patient_Id = 12739

Tables Updated:
    biometricinfo
    biometricverificationinfo

WARNING:
    ⚠ This permanently deletes biometric records.
    ⚠ Verify the patient before execution.
    ⚠ Run the backup queries first.
    ⚠ Re-enroll the patient's biometrics immediately after deletion.

===============================================================================
*/

-- ============================================================================
-- STEP 1: BACKUP CURRENT RECORDS
-- ============================================================================

SELECT *
FROM biometricinfo
WHERE patient_Id = 12739;

SELECT *
FROM biometricverificationinfo
WHERE patient_Id = 12739;

-- ============================================================================
-- STEP 2: DELETE BIOMETRIC VERIFICATION (RECAPTURE)
-- ============================================================================

DELETE
FROM biometricverificationinfo
WHERE patient_Id = 12739;

-- ============================================================================
-- STEP 3: DELETE BIOMETRIC ENROLLMENT (CAPTURE)
-- ============================================================================

DELETE
FROM biometricinfo
WHERE patient_Id = 12739;

-- ============================================================================
-- STEP 4: VERIFY DELETION
-- ============================================================================

SELECT *
FROM biometricinfo
WHERE patient_Id = 12739;

SELECT *
FROM biometricverificationinfo
WHERE patient_Id = 12739;