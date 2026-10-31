# What the tables show (and what they do not)

**The data is synthetic.** The Kaggle data card says the dataset "is synthetic and was generated for educational
purposes" (see [DATA.md](../DATA.md)). The 2,149 rows are not patients. Every pattern below describes how the
generator assigned values. None of it is a clinical, causal or risk finding, and none of it should be used for
any decision about a person.

All numbers come from `julia --project=. alzheimers_data_analysis.jl` and are in `results/`. Proportions are
"rows with Diagnosis = 1 in the group / rows in the group", with Wilson 95% intervals. The intervals describe
sampling uncertainty *within this synthetic sample* only. No tests or models were fitted, and many groups were
compared, so some differences of this size would appear by chance.

## Cleaning

2,149 rows read; 0 removed for missing values, 0 duplicate rows, 0 duplicate PatientIDs, 0 rows with codes or
values outside the data card's documented ranges (`results/cleaning_report.csv`, `results/validation.csv`).

## The original script's tables (`results/cases_*.csv`)

These are shares **among the 760 rows with Diagnosis = 1**, not rates. For example, "103 of 760 cases have
diabetes" says nothing about whether diabetes is more common among cases, because most rows (1,825 of 2,149)
have no diabetes at all.

| Table | Result (denominator 760) |
|---|---|
| Diabetes | No 657 (86.4%), Yes 103 (13.6%) |
| Gender | Male 386 (50.8%), Female 374 (49.2%) |
| Smoking | No 543 (71.4%), Yes 217 (28.6%) |
| Age | mean 74.8, median 75, SD 9.15, range 60–90 |

## Share with Diagnosis = 1, by group (`results/prevalence_by_group.csv`)

Overall: 760 / 2,149 = 35.4% (95% interval 33.4–37.4%).

| Group | Share with Diagnosis = 1 (cases / n) | 95% interval |
|---|---|---|
| Age 60–64 | 38.2% (130/340) | 33.2–43.5% |
| Age 65–69 | 33.2% (120/361) | 28.6–38.3% |
| Age 70–74 | 33.9% (121/357) | 29.2–39.0% |
| Age 75–79 | 35.8% (124/346) | 31.0–41.0% |
| Age 80–84 | 35.5% (119/335) | 30.6–40.8% |
| Age 85–90 | 35.6% (146/410) | 31.1–40.4% |
| Male / Female | 36.4% (386/1061) / 34.4% (374/1088) | 33.5–39.3% / 31.6–37.2% |
| Smoking No / Yes | 35.5% (543/1529) / 35.0% (217/620) | 33.2–37.9% / 31.3–38.8% |
| Diabetes No / Yes | 36.0% (657/1825) / 31.8% (103/324) | 33.8–38.2% / 27.0–37.0% |
| Depression No / Yes | 35.5% (610/1718) / 34.8% (150/431) | 33.3–37.8% / 30.5–39.4% |
| Family history No / Yes | 36.3% (583/1607) / 32.7% (177/542) | 34.0–38.7% / 28.8–36.7% |
| Memory complaints No / Yes | 27.8% (474/1702) / 64.0% (286/447) | 25.8–30.0% / 59.4–68.3% |
| Behavioural problems No / Yes | 30.7% (557/1812) / 60.2% (203/337) | 28.7–32.9% / 54.9–65.3% |

Figure: `results/figures/diagnosis_share_by_group.svg` (every point is labelled with cases/n).

What can be said, about this synthetic sample only:

- Across age bands, sex, smoking, diabetes, depression and family history the shares sit close to the overall
  35.4%, and the intervals overlap. The generator does not appear to have made these columns strongly
  related to the label. This is **not** evidence about whether these factors relate to Alzheimer's disease in
  real people; this dataset cannot answer that question.
- Rows flagged with memory complaints or behavioural problems are labelled Diagnosis = 1 about twice as often
  as rows without them. These look like symptom-type columns, so the pattern is close to circular, and it again
  reflects the generator.

## Scores by diagnosis (`results/scores_by_diagnosis.csv`)

| Score | Diagnosis = 0 (n = 1,389) mean (SD), median | Diagnosis = 1 (n = 760) mean (SD), median |
|---|---|---|
| MMSE (0–30) | 16.3 (8.9), 17.1 | 12.0 (7.2), 11.6 |
| Functional assessment (0–10) | 5.9 (2.8), 6.2 | 3.7 (2.6), 3.3 |
| ADL (0–10) | 5.7 (2.8), 6.1 | 3.7 (2.7), 3.2 |

Figure: `results/figures/mmse_by_diagnosis.svg` (counts per 3-point bin; group sizes in the legend). MMSE values
look roughly uniform for Diagnosis = 0, and only 20 of the 415 rows with MMSE ≥ 24 have Diagnosis = 1. In this
dataset the label appears to have been generated partly from these scores, so they "separate" the groups by
construction. This is not a statement about the MMSE as a clinical test.

## Limits

- Synthetic data; patterns are properties of the generator.
- Descriptive only: no adjustment, no models, no multiple-comparison correction.
- The CSV in this repository has the size, row count, columns and placeholder values of Kaggle version 1, but it
  was not compared byte for byte with a fresh download (see DATA.md).
