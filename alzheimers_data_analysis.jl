# Entry point. Run from the repository folder:
#   julia --project=. alzheimers_data_analysis.jl [--data FILE] [--out DIR] [--min-age N]
# Part 1 reproduces the original tables (now with denominators). Part 2 adds descriptive tables with 95% intervals
# and two SVG figures. All outputs go to results/. The data is synthetic: nothing here is a clinical finding.
using CSV, DataFrames, PrettyTables
include(joinpath(@__DIR__, "src", "AlzheimersEDA.jl"))
using .AlzheimersEDA

const DEFAULT_OUT = joinpath(@__DIR__, "results")
const MMSE_EDGES = collect(0:3:30)

function parse_args(args)
    opts = Dict("data" => joinpath(@__DIR__, "alzheimers_disease_data.csv"), "out" => DEFAULT_OUT,
                "min-age" => "70")
    i = 1
    while i <= length(args)
        key = replace(args[i], r"^--" => "")
        (haskey(opts, key) && i < length(args)) || (println(stderr, "usage: julia --project=. alzheimers_data_analysis.jl [--data FILE] [--out DIR] [--min-age N]"); exit(2))
        opts[key] = args[i + 1]
        i += 2
    end
    min_age = tryparse(Float64, opts["min-age"])
    min_age === nothing && (println(stderr, "error: --min-age must be a number, got \"$(opts["min-age"])\""); exit(2))
    return opts["data"], opts["out"], min_age
end

function show_table(title, df)
    println(title)
    nrow(df) == 0 ? println("  (no rows match this selection)") :
        pretty_table(df; fit_table_in_display_horizontally = false, fit_table_in_display_vertically = false)
end

function main(args)
    data_path, out_dir, min_age = parse_args(args)
    raw = load_data(data_path)
    clean, report = clean_data(raw)
    mkpath(out_dir)

    println("Data: synthetic Kaggle Alzheimer's Disease Dataset (CC BY 4.0, see DATA.md). Not real patients.")
    println("Cleaning: $(report.rows_in) rows read, $(report.removed_missing) removed for missing values, " *
            "$(report.removed_duplicates) duplicate rows removed, $(report.removed_invalid_codes) removed for invalid codes, " *
            "$(report.rows_out) rows used.")
    invalid = filter(r -> r.n_invalid > 0 || r.n_missing > 0, validate_data(raw))
    println(nrow(invalid) == 0 ? "Validation: all documented codes and ranges respected." : "Validation issues:")
    nrow(invalid) == 0 || pretty_table(invalid)

    sorted = sort(clean, :Diagnosis, rev = true)
    show_table("Sorted clean data (first 5 rows):", first(sorted, 5))
    older = select_rows(clean; min_age = min_age)
    show_table("First 5 rows with age > $(min_age) ($(nrow(older)) of $(nrow(clean)) rows):", first(older, 5))

    cases = select_rows(clean; diagnosis = 1)
    println("Rows with Diagnosis = 1 (Alzheimer's in the synthetic data): $(nrow(cases)) of $(nrow(clean)).")
    by_diabetes = count_by(cases, :Diabetes)
    show_table("Cases by diabetes (share of cases, not a risk):", by_diabetes)
    ages = age_summary(cases)
    show_table("Age of cases:", ages)
    by_gender = count_by(cases, :Gender)
    show_table("Gender of cases:", by_gender)
    by_smoking = count_by(cases, :Smoking)
    show_table("Smoking among cases:", by_smoking)

    CSV.write(joinpath(out_dir, "cleaning_report.csv"), DataFrame([report]))
    CSV.write(joinpath(out_dir, "validation.csv"), validate_data(raw))
    CSV.write(joinpath(out_dir, "cases_by_diabetes.csv"), by_diabetes)
    CSV.write(joinpath(out_dir, "cases_age_summary.csv"), ages)
    CSV.write(joinpath(out_dir, "cases_by_gender.csv"), by_gender)
    CSV.write(joinpath(out_dir, "cases_by_smoking.csv"), by_smoking)

    # Part 2: descriptive tables over more columns (E2.03).
    full, full_report = clean_data(raw; columns = ANALYSIS_COLUMNS)
    println()
    println("Descriptive tables: $(full_report.rows_out) rows after the same cleaning over $(length(ANALYSIS_COLUMNS)) columns.")
    println("Proportion = rows with Diagnosis = 1 in the group / rows in the group, with a Wilson 95% interval.")
    println("These describe how the synthetic generator assigned diagnoses; they are not risks, causes or clinical findings.")
    k = count(==(1), full.Diagnosis); n = nrow(full); lo, hi = wilson_ci(k, n)
    println("All rows: $k/$n = $(round(100k / n; digits = 1))% (95% interval $(round(100lo; digits = 1))–$(round(100hi; digits = 1))%)")
    prev = vcat(prevalence_by(full, :AgeBand), (prevalence_by(full, c) for c in PREVALENCE_COLUMNS)...)
    show_table("Diagnosis = 1 by group:", transform(prev, [:proportion, :ci95_low, :ci95_high] .=> ByRow(x -> round(x; digits = 3)); renamecols = false))
    numeric = vcat((numeric_by_diagnosis(full, c) for c in (:MMSE, :FunctionalAssessment, :ADL))...)
    show_table("Scores by diagnosis (MMSE 0–30, FunctionalAssessment 0–10, ADL 0–10):",
               transform(numeric, Not([:variable, :diagnosis, :n]) .=> ByRow(x -> round(x; digits = 2)); renamecols = false))

    r6(df) = transform(df, names(df, Float64) .=> ByRow(x -> round(x; digits = 6)); renamecols = false)
    CSV.write(joinpath(out_dir, "prevalence_by_group.csv"), r6(prev))
    CSV.write(joinpath(out_dir, "scores_by_diagnosis.csv"), r6(numeric))
    fig_dir = joinpath(out_dir, "figures")
    mkpath(fig_dir)
    write(joinpath(fig_dir, "diagnosis_share_by_group.svg"),
          svg_prevalence(prev, "Share of rows with Diagnosis = 1, by group (synthetic data, n = $n)"; overall = k / n))
    write(joinpath(fig_dir, "mmse_by_diagnosis.svg"),
          svg_histogram(full, :MMSE, MMSE_EDGES, "MMSE score by diagnosis (synthetic data, n = $n)"))
    println("Tables and figures written to $(out_dir == DEFAULT_OUT ? "results/" : out_dir).")
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    try
        exit(main(ARGS))
    catch e
        e isa ArgumentError || rethrow()
        println(stderr, "error: ", e.msg)
        exit(2)
    end
end
