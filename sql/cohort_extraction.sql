-- cohort_extraction.sql
-- Project: Insurance Type & ICU Length of Stay in Sepsis-3 Patients
-- Data source: MIMIC-IV v3.1 on PhysioNet / Google BigQuery
--
-- Purpose:
--   Build the primary analytic cohort used in the portfolio analysis.
--
-- Primary cohort definition:
--   1. ICU stays meeting the MIMIC-IV derived Sepsis-3 definition
--   2. Insurance recorded as Medicare, Medicaid, or Private
--   3. First qualifying ICU stay per patient
--
-- Notes:
--   - ICU length of stay (icu_los) is the primary outcome.
--   - Insurance is the primary exposure.
--   - SOFA score is used as a measure of illness severity.
--   - Race and admission type are retained in their raw MIMIC-IV form here
--     and consolidated into broader categories in the Python analysis notebook.
--   - The first qualifying stay is selected AFTER restricting to the three
--     payer groups, matching the primary analysis implemented in Python.
--
-- Expected primary cohort size from the analysis: 24,534 patients.

WITH eligible_stays AS (
    SELECT
        s.subject_id,
        s.stay_id,
        i.hadm_id,

        -- ICU information / primary outcome
        i.intime AS icu_intime,
        i.los AS icu_los,

        -- Primary exposure
        a.insurance,

        -- Demographics
        p.gender,
        p.anchor_age AS age,
        a.race,

        -- Illness severity
        s.sofa_score,

        -- Admission characteristics
        a.admission_type,

        -- Secondary descriptive outcome
        a.hospital_expire_flag,

        -- Rank qualifying ICU stays chronologically within patient
        ROW_NUMBER() OVER (
            PARTITION BY s.subject_id
            ORDER BY i.intime, s.stay_id
        ) AS qualifying_stay_number

    FROM `physionet-data.mimiciv_3_1_derived.sepsis3` AS s

    INNER JOIN `physionet-data.mimiciv_3_1_icu.icustays` AS i
        ON s.stay_id = i.stay_id

    INNER JOIN `physionet-data.mimiciv_3_1_hosp.admissions` AS a
        ON i.hadm_id = a.hadm_id

    INNER JOIN `physionet-data.mimiciv_3_1_hosp.patients` AS p
        ON s.subject_id = p.subject_id

    WHERE
        s.sepsis3 = TRUE
        AND a.insurance IN ('Medicare', 'Medicaid', 'Private')
)

SELECT
    subject_id,
    stay_id,
    hadm_id,
    icu_intime,
    icu_los,
    insurance,
    gender,
    age,
    race,
    sofa_score,
    admission_type,
    hospital_expire_flag
FROM eligible_stays
WHERE qualifying_stay_number = 1
ORDER BY subject_id;
