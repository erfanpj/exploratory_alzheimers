"""
Descriptive analysis of the synthetic Kaggle Alzheimer's Disease Dataset (see DATA.md).
Nothing here is a clinical or causal finding: the data is synthetic.
"""
module AlzheimersEDA

using CSV, DataFrames, Statistics

export load_data, validate_data, clean_data, select_rows, age_summary, count_by, label_codes,
       MAIN_COLUMNS, CODE_LABELS

# Columns used by the original analysis.
const MAIN_COLUMNS = [:Age, :Gender, :Smoking, :Diabetes, :Depression, :Diagnosis]

# Allowed codes and readable labels, from the Kaggle data card.
const CODE_LABELS = Dict{Symbol,Dict{Int,String}}(
    :Gender => Dict(0 => "Male", 1 => "Female"),
    :Ethnicity => Dict(0 => "Caucasian", 1 => "African American", 2 => "Asian", 3 => "Other"),
    :EducationLevel => Dict(0 => "None", 1 => "High School", 2 => "Bachelor's", 3 => "Higher"),
    (c => Dict(0 => "No", 1 => "Yes") for c in (:Smoking, :FamilyHistoryAlzheimers, :CardiovascularDisease,
        :Diabetes, :Depression, :HeadInjury, :Hypertension, :MemoryComplaints, :BehavioralProblems, :Confusion,
        :Disorientation, :PersonalityChanges, :DifficultyCompletingTasks, :Forgetfulness, :Diagnosis))...,
)

# Documented ranges for numeric columns (data card).
const RANGES = Dict(:Age => (60, 90), :BMI => (15, 40), :AlcoholConsumption => (0, 20), :PhysicalActivity => (0, 10),
    :DietQuality => (0, 10), :SleepQuality => (4, 10), :SystolicBP => (90, 180), :DiastolicBP => (60, 120),
    :CholesterolTotal => (150, 300), :CholesterolLDL => (50, 200), :CholesterolHDL => (20, 100),
    :CholesterolTriglycerides => (50, 400), :MMSE => (0, 30), :FunctionalAssessment => (0, 10), :ADL => (0, 10))

"""
    load_data(path) -> DataFrame

Read the CSV. Fails with a clear message if the file or a required column is missing.
"""
function load_data(path::AbstractString)
    isfile(path) || throw(ArgumentError("data file not found: $path (see DATA.md for the source)"))
    df = CSV.read(path, DataFrame; missingstring = ["", "NA"])
    missing_cols = setdiff(vcat(MAIN_COLUMNS, [:PatientID]), Symbol.(names(df)))
    isempty(missing_cols) || throw(ArgumentError("required columns missing: $(join(missing_cols, ", "))"))
    return df
end

"""
    validate_data(df) -> DataFrame

One row per checked column: missing values, values outside the documented codes or ranges.
"""
function validate_data(df::AbstractDataFrame)
    rows = NamedTuple{(:column, :rule, :n_missing, :n_invalid),Tuple{String,String,Int,Int}}[]
    for col in Symbol.(names(df))
        v = df[!, col]
        nmiss = count(ismissing, v)
        if haskey(CODE_LABELS, col)
            allowed = keys(CODE_LABELS[col])
            push!(rows, (column = String(col), rule = "codes $(join(sort(collect(allowed)), "/"))", n_missing = nmiss,
                         n_invalid = count(x -> !ismissing(x) && !(x isa Real && isinteger(x) && Int(x) in allowed), v)))
        elseif haskey(RANGES, col)
            lo, hi = RANGES[col]
            push!(rows, (column = String(col), rule = "range $(lo)–$(hi)", n_missing = nmiss,
                         n_invalid = count(x -> !ismissing(x) && !(x isa Real && lo <= x <= hi), v)))
        end
    end
    return DataFrame(rows)
end

"""
    clean_data(df; columns = MAIN_COLUMNS) -> (clean::DataFrame, report::NamedTuple)

Same steps as the original script (drop rows with missing values, drop duplicate rows, keep the main columns), plus
removal of rows whose codes are invalid, with a count for every step. The input is not modified.
"""
function clean_data(df::AbstractDataFrame; columns = MAIN_COLUMNS)
    data = copy(df)
    rows_in = nrow(data)
    dropmissing!(data)
    after_missing = nrow(data)
    unique!(data)
    after_dupes = nrow(data)
    dup_ids = hasproperty(data, :PatientID) ? nrow(data) - length(unique(data.PatientID)) : 0
    select!(data, columns)
    valid = trues(nrow(data))
    for col in columns
        if haskey(CODE_LABELS, col)
            allowed = keys(CODE_LABELS[col])
            valid .&= [x isa Real && isinteger(x) && Int(x) in allowed for x in data[!, col]]
        elseif haskey(RANGES, col)
            lo, hi = RANGES[col]
            valid .&= [x isa Real && lo <= x <= hi for x in data[!, col]]
        end
    end
    clean = data[valid, :]
    report = (rows_in = rows_in, removed_missing = rows_in - after_missing, removed_duplicates = after_missing - after_dupes,
              duplicate_patient_ids = dup_ids, removed_invalid_codes = nrow(data) - nrow(clean), rows_out = nrow(clean))
    return clean, report
end

"""
    select_rows(df; min_age = nothing, max_age = nothing, diagnosis = nothing) -> DataFrame

Filter rows. Invalid arguments throw an ArgumentError; a selection with no rows returns an empty DataFrame.
"""
function select_rows(df::AbstractDataFrame; min_age = nothing, max_age = nothing, diagnosis = nothing)
    for (name, v) in (("min_age", min_age), ("max_age", max_age))
        v === nothing || (v isa Real && isfinite(v)) || throw(ArgumentError("$name must be a number, got $(repr(v))"))
    end
    min_age !== nothing && max_age !== nothing && min_age > max_age &&
        throw(ArgumentError("min_age ($min_age) is greater than max_age ($max_age)"))
    diagnosis === nothing || diagnosis in (0, 1) || throw(ArgumentError("diagnosis must be 0 or 1, got $(repr(diagnosis))"))
    keep = trues(nrow(df))
    min_age === nothing || (keep .&= df.Age .> min_age)       # strictly greater, as in the original script
    max_age === nothing || (keep .&= df.Age .<= max_age)
    diagnosis === nothing || (keep .&= df.Diagnosis .== diagnosis)
    return df[keep, :]
end

"""
    age_summary(df) -> DataFrame

n, mean, median, standard deviation, min and max of Age. For an empty selection n is 0 and the statistics are
`missing` (the original script would fail on an empty selection).
"""
function age_summary(df::AbstractDataFrame)
    n = nrow(df)
    stat(f) = n == 0 ? missing : f(df.Age)
    sd = n < 2 ? missing : std(df.Age)
    return DataFrame(Statistic = ["n", "Mean", "Median", "Std Dev", "Min", "Max"],
                     Value = Union{Missing,Float64}[n, stat(mean), stat(median), sd, stat(minimum), stat(maximum)])
end

"""
    label_codes(col, values) -> Vector{String}

Readable labels for coded values; unknown codes throw instead of being silently mislabelled.
"""
function label_codes(col::Symbol, values)
    haskey(CODE_LABELS, col) || throw(ArgumentError("no labels defined for $col"))
    labels = CODE_LABELS[col]
    return [haskey(labels, Int(v)) ? labels[Int(v)] : throw(ArgumentError("unknown code $v in $col")) for v in values]
end

"""
    count_by(df, col) -> DataFrame

Counts per group with the denominator (total rows in `df`) and the share. Works for an empty DataFrame.
"""
function count_by(df::AbstractDataFrame, col::Symbol)
    total = nrow(df)
    total == 0 && return DataFrame(group = String[], count = Int[], denominator = Int[], share = Float64[])
    g = combine(groupby(df, col; sort = true), nrow => :count)
    groups = haskey(CODE_LABELS, col) ? label_codes(col, g[!, col]) : string.(g[!, col])
    return DataFrame(group = groups, count = g.count, denominator = fill(total, nrow(g)), share = g.count ./ total)
end

end # module
