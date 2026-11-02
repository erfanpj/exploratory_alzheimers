# Data: source, licence and what it is

## Source
`alzheimers_disease_data.csv` is the **Alzheimer's Disease Dataset** by Rabie El Kharoua, published on Kaggle in 2024:
<https://www.kaggle.com/datasets/rabieelkharoua/alzheimers-disease-dataset>, DOI
[10.34740/KAGGLE/DSV/8668279](https://doi.org/10.34740/KAGGLE/DSV/8668279) (version 1, "Initial release", 11 June 2024).

Cite it as:
> Rabie El Kharoua (2024). *Alzheimer's Disease Dataset*. Kaggle. https://doi.org/10.34740/KAGGLE/DSV/8668279

## Licence
The dataset is published under **Creative Commons Attribution 4.0 International (CC BY 4.0)**
(<https://creativecommons.org/licenses/by/4.0/>), according to the Kaggle data card and dataset metadata
(checked 31 October 2026). CC BY 4.0 allows sharing and adapting the data with attribution. The file in this
repository is the unmodified original; this project does not change it.

**The MIT licence in [LICENSE](LICENSE) covers the Julia code and documentation only, not this data file.**

## It is synthetic, not real patient data
The data card states: "This dataset is synthetic and was generated for educational purposes." The dataset is also
tagged *synthetic* on Kaggle. The rows are not real patients. How the data was generated is not documented, so:
- relationships between columns reflect the author's generator, not real-world medicine;
- no result from this project says anything about Alzheimer's disease in real people.

## Is this the same file as on Kaggle?
The original download date of the bundled copy is not recorded (it was committed on 3 February 2025). It matches the
published dataset on every check that does not require a Kaggle login:

| Check | Kaggle | This file |
|---|---|---|
| Size in bytes | 605,247 (dataset metadata) | 605,247 |
| Versions | 1 | – |
| Rows (patients) | 2,149 | 2,149 |
| Columns | 35 (data card) | 35 |
| `DoctorInCharge` | "XXXConfid" for all rows | "XXXConfid" for all 2,149 rows |

SHA-256 of the bundled file: `66f51dbb5f00a4bf6ed1f631e72ec15e4a8e97dc223c10f78c1febec95a2be07`.
A byte-for-byte comparison would need a Kaggle download, which was not done. One small inconsistency in the data card:
it gives patient IDs "4751 to 6900" (2,150 numbers), while the file has 2,149 unique IDs from 4751 to 6899.

## Columns (from the data card)
| Group | Columns and coding |
|---|---|
| ID | `PatientID` (4751–6899) |
| Demographics | `Age` 60–90; `Gender` 0 = Male, 1 = Female; `Ethnicity` 0 = Caucasian, 1 = African American, 2 = Asian, 3 = Other; `EducationLevel` 0 = None, 1 = High School, 2 = Bachelor's, 3 = Higher |
| Lifestyle | `BMI` 15–40; `Smoking` 0/1; `AlcoholConsumption` 0–20 units/week; `PhysicalActivity` 0–10 h/week; `DietQuality` 0–10; `SleepQuality` 4–10 |
| Medical history (0 = No, 1 = Yes) | `FamilyHistoryAlzheimers`, `CardiovascularDisease`, `Diabetes`, `Depression`, `HeadInjury`, `Hypertension` |
| Clinical measurements | `SystolicBP` 90–180; `DiastolicBP` 60–120 mmHg; `CholesterolTotal` 150–300; `CholesterolLDL` 50–200; `CholesterolHDL` 20–100; `CholesterolTriglycerides` 50–400 mg/dL |
| Cognitive and functional | `MMSE` 0–30 (lower = more impairment); `FunctionalAssessment` 0–10; `ADL` 0–10; `MemoryComplaints`, `BehavioralProblems` 0/1 |
| Symptoms (0/1) | `Confusion`, `Disorientation`, `PersonalityChanges`, `DifficultyCompletingTasks`, `Forgetfulness` |
| Label | `Diagnosis` 0 = No, 1 = Yes (Alzheimer's disease) |
| Placeholder | `DoctorInCharge` = "XXXConfid" in every row |
