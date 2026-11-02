# Alzheimer's data analysis in Julia (synthetic data)

A small descriptive analysis of the **synthetic** Kaggle *Alzheimer's Disease Dataset* in Julia: data cleaning
with recorded counts, validation against the data card, the original summary tables with their denominators,
and a few extra tables and figures with 95% intervals.

> **The data is synthetic.** Its author describes it as "synthetic and ... generated for educational purposes".
> The rows are not patients. The results describe the data generator, not Alzheimer's disease, and nothing
> here is a clinical, causal or risk finding. See [DATA.md](DATA.md) and [docs/findings.md](docs/findings.md).

## Run it

Requires Julia 1.13 (tested with 1.13.3 on Linux x86_64). Package versions are pinned in `Manifest.toml`.

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'     # once: installs CSV, DataFrames, PrettyTables
julia --project=. alzheimers_data_analysis.jl            # prints the tables and writes results/
julia --project=. -e 'using Pkg; Pkg.test()'             # 49 tests
```

Options: `--data FILE` (default: the bundled CSV), `--out DIR` (default `results/`), `--min-age N` (default 70;
the script shows rows with age strictly greater than N, as the original did). A non-numeric `--min-age`, an
unknown option or a missing data file stops the script with exit status 2 and a message. A selection with no
matching rows prints "(no rows match this selection)" instead of failing.

## What it does

1. **Load and validate** `alzheimers_disease_data.csv`: required columns, codes (for example Gender 0/1) and
   documented value ranges. All 2,149 rows pass (`results/validation.csv`).
2. **Clean** with a count for each step: missing values, duplicate rows, duplicate patient IDs and invalid codes.
   For this file every count is 0 and all 2,149 rows are used (`results/cleaning_report.csv`).
3. **Original tables**, kept from the first version of the script and now with denominators: among the 760 rows
   with Diagnosis = 1, counts by diabetes, gender and smoking, and the age summary (`results/cases_*.csv`).
   These are shares of cases, not rates.
4. **Descriptive tables**: the share of rows with Diagnosis = 1 by age band, gender, smoking, diabetes,
   depression, family history, memory complaints and behavioural problems, each with cases, n and a Wilson 95%
   interval (`results/prevalence_by_group.csv`); MMSE, functional assessment and ADL by diagnosis
   (`results/scores_by_diagnosis.csv`).
5. **Figures** written as plain SVG by the project code, each labelled with its denominators:
   `results/figures/diagnosis_share_by_group.svg` and `results/figures/mmse_by_diagnosis.svg`.

In short: 760 of 2,149 rows (35.4%) have Diagnosis = 1. Across age bands, gender, smoking, diabetes, depression and
family history the share stays near that overall figure. It is about twice as high in rows with memory complaints
or behavioural problems, and diagnosed rows have lower MMSE, functional assessment and ADL scores. All of these
are properties of the synthetic generator; [docs/findings.md](docs/findings.md) gives the numbers and the limits.

## Files

| Path | What it is |
|---|---|
| `alzheimers_data_analysis.jl` | Entry point |
| `src/AlzheimersEDA.jl` | Loading, validation, cleaning, selections, tables and SVG figures |
| `test/runtests.jl` | Tests on small hand-made tables and on the bundled file |
| `results/` | Outputs of the entry point, committed so they can be read without running anything |
| `docs/findings.md` | What the tables show and do not show |
| `DATA.md` | Data source, licence, synthetic status, identity checks and column dictionary |

## Data and licence

The data is the *Alzheimer's Disease Dataset* by Rabie El Kharoua (Kaggle, 2024,
[doi:10.34740/KAGGLE/DSV/8668279](https://doi.org/10.34740/KAGGLE/DSV/8668279)), licensed
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The CSV here is the unmodified original; details and
caveats are in [DATA.md](DATA.md).

The code and documentation are under the MIT licence ([LICENSE](LICENSE)). **The MIT licence does not cover the
data file**, which stays under CC BY 4.0.

## History and AI assistance

I wrote the first version (one script with the cleaning, filters and the diabetes, gender, smoking and age
tables) in February 2025. In October 2026 I restructured it with help from an AI coding assistant (Grok Bot):
the data provenance notes, the module, tests, pinned environment, validation and cleaning counts, the interval
tables, the SVG figures and this README. The original tables are kept, and the tests check that they give the
same numbers as the first version.
