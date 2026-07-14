# Restore / Re-enroll Patient Biometrics

## Purpose

After deleting a patient's biometric records from the NMRS database, the patient
must be enrolled again through the NMRS Biometric Capture application.

---

## Workflow

1. Verify that the patient's biometric records have been deleted.

```sql
SELECT *
FROM biometricinfo
WHERE patient_Id = <patient_id>;

SELECT *
FROM biometricverificationinfo
WHERE patient_Id = <patient_id>;
```

Both queries should return **0 rows**.

---

2. Open NMRS.

3. Navigate to the patient's record.

4. Open the **Biometric Capture (PBS)** module.

5. Capture all required fingerprints.

6. Save the enrollment.

7. If your implementation supports biometric verification/recapture,
   perform a verification test.

---

## Verification

Confirm that new records have been created.

```sql
SELECT *
FROM biometricinfo
WHERE patient_Id = <patient_id>;

SELECT *
FROM biometricverificationinfo
WHERE patient_Id = <patient_id>;
```

The patient should now have newly generated biometric records.

---

## Notes

- Never restore records by manually inserting templates into the database.
- Always use the NMRS application to perform biometric enrollment.
- Manual database inserts can result in invalid templates, UUID conflicts,
  or synchronization failures.
- If synchronization with the central server is enabled, ensure that the
  patient syncs successfully after re-enrollment.