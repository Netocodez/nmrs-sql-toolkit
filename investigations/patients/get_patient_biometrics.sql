/*
===============================================================================
Name:
    Get Patient Biometrics

Category:
    Patient Investigation

Purpose:
    Retrieves all biometric enrollment and verification records associated
    with a patient.

===============================================================================
*/

-- ============================================================================
-- BIOMETRIC ENROLLMENT (CAPTURE)
-- ============================================================================

SELECT *
FROM biometricinfo
WHERE patient_Id = 12739;

-- ============================================================================
-- BIOMETRIC VERIFICATION (RECAPTURE)
-- ============================================================================

SELECT *
FROM biometricverificationinfo
WHERE patient_Id = 12739;