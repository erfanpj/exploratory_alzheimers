"""
Descriptive analysis of the synthetic Kaggle Alzheimer's Disease Dataset (see DATA.md).
Nothing here is a clinical or causal finding: the data is synthetic.
"""
module AlzheimersEDA

using CSV, DataFrames, Statistics

export load_data, validate_data, clean_data, select_rows, age_summary, count_by, label_codes,
       wilson_ci, age_band, prevalence_by, numeric_by_diagnosis, svg_prevalence, svg_histogram,
       MAIN_COLUMNS, ANALYSIS_COLUMNS, PREVALENCE_COLUMNS, CODE_LABELS

# Columns used by the original analysis.
const MAIN_COLUMNS = [:Age, :Gender, :Smoking, :Diabetes, :Depression, :Diagnosis]

# Columns used by the descriptive analysis (E2.03).
const PREVALENCE_COLUMNS = [:Gender, :Smoking, :Diabetes, :Depression, :FamilyHistoryAlzheimers,
                            :MemoryComplaints, :BehavioralProblems]
const ANALYSIS_COLUMNS = unique(vcat(MAIN_COLUMNS, PREVALENCE_COLUMNS, [:MMSE, :FunctionalAssessment, :ADL]))

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

"""
    wilson_ci(k, n; z = 1.959964) -> (lo, hi)

Wilson score interval for a proportion k/n (95% by default). Returns `(missing, missing)` when n is 0.
"""
function wilson_ci(k::Integer, n::Integer; z = 1.959964)
    (0 <= k <= n) || throw(ArgumentError("need 0 <= k <= n, got k=$k, n=$n"))
    n == 0 && return (missing, missing)
    p = k / n
    centre = (p + z^2 / (2n)) / (1 + z^2 / n)
    half = z * sqrt(p * (1 - p) / n + z^2 / (4n^2)) / (1 + z^2 / n)
    return (max(0.0, centre - half), min(1.0, centre + half))
end

"""
    age_band(age) -> String

Five-year bands over the documented 60–90 range; the last band is 85–90 because 90 is the documented maximum.
"""
function age_band(age::Real)
    (60 <= age <= 90) || throw(ArgumentError("age $age outside the documented 60–90 range"))
    lo = min(60 + 5 * fld(Int(floor(age)) - 60, 5), 85)
    return lo == 85 ? "85–90" : "$(lo)–$(lo + 4)"
end

"""
    prevalence_by(df, col) -> DataFrame

For each group of `col` (or `:AgeBand`): rows `n`, rows with Diagnosis = 1 `cases`, the proportion and a Wilson 95%
interval. Proportions describe this synthetic sample only.
"""
function prevalence_by(df::AbstractDataFrame, col::Symbol)
    out = DataFrame(variable = String[], group = String[], n = Int[], cases = Int[], proportion = Float64[],
                    ci95_low = Float64[], ci95_high = Float64[])
    nrow(df) == 0 && return out
    key = col == :AgeBand ? age_band.(df.Age) : df[!, col]
    tmp = DataFrame(key = key, dx = df.Diagnosis)
    g = combine(groupby(tmp, :key; sort = true), nrow => :n, :dx => (x -> count(==(1), x)) => :cases)
    labels = col == :AgeBand ? string.(g.key) : (haskey(CODE_LABELS, col) ? label_codes(col, g.key) : string.(g.key))
    for (lab, n, k) in zip(labels, g.n, g.cases)
        lo, hi = wilson_ci(k, n)
        push!(out, (String(col), lab, n, k, k / n, lo, hi))
    end
    return out
end

"""
    numeric_by_diagnosis(df, col) -> DataFrame

n, mean, standard deviation, quartiles, min and max of a numeric column, split by Diagnosis.
"""
function numeric_by_diagnosis(df::AbstractDataFrame, col::Symbol)
    out = DataFrame(variable = String[], diagnosis = String[], n = Int[], mean = Float64[], sd = Float64[],
                    q1 = Float64[], median = Float64[], q3 = Float64[], min = Float64[], max = Float64[])
    for d in (0, 1)
        v = Float64.(df[df.Diagnosis .== d, col])
        isempty(v) && continue
        q = quantile(v, [0.25, 0.5, 0.75])
        push!(out, (String(col), CODE_LABELS[:Diagnosis][d], length(v), mean(v), length(v) > 1 ? std(v) : NaN,
                    q[1], q[2], q[3], minimum(v), maximum(v)))
    end
    return out
end

_esc(s) = replace(string(s), "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")
_f(x) = string(round(x; digits = 1))

"""
    svg_prevalence(tbl, title) -> String

Dot-and-interval chart of `prevalence_by` rows: one line per group with the proportion, its 95% interval and the
label "cases/n", so every point shows its denominator. The axis runs from 0 to 100%.
"""
function svg_prevalence(tbl::AbstractDataFrame, title::AbstractString; overall = nothing)
    left, right, top, rowh = 300, 140, 76, 22
    plotw = 420
    nrows = nrow(tbl) + count(i -> i == 1 || tbl.variable[i] != tbl.variable[i-1], 1:nrow(tbl))
    h = top + rowh * nrows + 50
    w = left + plotw + right
    x(p) = left + p * plotw
    io = IOBuffer()
    print(io, """<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h" viewBox="0 0 $w $h" font-family="sans-serif" font-size="12">\n""")
    print(io, """<rect width="$w" height="$h" fill="white"/>\n""")
    print(io, """<text x="10" y="20" font-size="14" font-weight="bold">$(_esc(title))</text>\n""")
    print(io, """<text x="10" y="38" fill="#555">Synthetic data. Share of rows with Diagnosis = 1 per group, with Wilson 95% intervals. Labels: cases/n.</text>\n""")
    for t in 0:0.25:1
        print(io, """<line x1="$(_f(x(t)))" y1="$(top - 8)" x2="$(_f(x(t)))" y2="$(h - 40)" stroke="#ddd"/>""")
        print(io, """<text x="$(_f(x(t)))" y="$(h - 24)" text-anchor="middle" fill="#555">$(Int(t * 100))%</text>\n""")
    end
    if overall !== nothing
        print(io, """<line x1="$(_f(x(overall)))" y1="$(top - 8)" x2="$(_f(x(overall)))" y2="$(h - 40)" stroke="#999" stroke-dasharray="4 3"/>""")
        print(io, """<text x="$(_f(x(overall)))" y="$(top - 12)" text-anchor="middle" fill="#555">all rows $(round(overall * 100; digits = 1))%</text>\n""")
    end
    y = top
    for i in 1:nrow(tbl)
        if i == 1 || tbl.variable[i] != tbl.variable[i-1]
            print(io, """<text x="10" y="$(y + 15)" font-weight="bold">$(_esc(tbl.variable[i]))</text>\n""")
            y += rowh
        end
        cy = y + 11
        print(io, """<text x="30" y="$(cy + 4)">$(_esc(tbl.group[i]))</text>""")
        print(io, """<line x1="$(_f(x(tbl.ci95_low[i])))" y1="$cy" x2="$(_f(x(tbl.ci95_high[i])))" y2="$cy" stroke="#1f5fa8" stroke-width="2"/>""")
        print(io, """<circle cx="$(_f(x(tbl.proportion[i])))" cy="$cy" r="4" fill="#1f5fa8"/>""")
        print(io, """<text x="$(left + plotw + 10)" y="$(cy + 4)">$(round(tbl.proportion[i] * 100; digits = 1))% ($(tbl.cases[i])/$(tbl.n[i]))</text>\n""")
        y += rowh
    end
    print(io, "</svg>\n")
    return String(take!(io))
end

"""
    svg_histogram(df, col, edges, title) -> String

Side-by-side counts of `col` per bin, split by Diagnosis, with the group sizes in the legend. Bins are [a, b) except
the last, which includes its upper edge.
"""
function svg_histogram(df::AbstractDataFrame, col::Symbol, edges::AbstractVector, title::AbstractString)
    nb = length(edges) - 1
    counts = zeros(Int, 2, nb)
    for (v, d) in zip(df[!, col], df.Diagnosis)
        b = v >= edges[end] ? nb : searchsortedlast(edges, v)
        (1 <= b <= nb) && (counts[d + 1, b] += 1)
    end
    ns = [count(==(0), df.Diagnosis), count(==(1), df.Diagnosis)]
    left, top, ploth, binw = 60, 92, 260, 36
    w = left + binw * nb + 40
    h = top + ploth + 60
    ymax = max(1, maximum(counts))
    yv(c) = top + ploth - c / ymax * ploth
    colors = ("#9aa5b1", "#1f5fa8")
    io = IOBuffer()
    print(io, """<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h" viewBox="0 0 $w $h" font-family="sans-serif" font-size="12">\n""")
    print(io, """<rect width="$w" height="$h" fill="white"/>\n""")
    print(io, """<text x="10" y="20" font-size="14" font-weight="bold">$(_esc(title))</text>\n""")
    for d in 0:1
        lx = 10 + d * 230
        print(io, """<rect x="$lx" y="32" width="12" height="12" fill="$(colors[d + 1])"/>""")
        print(io, """<text x="$(lx + 18)" y="42">Diagnosis = $d ($(CODE_LABELS[:Diagnosis][d])), n = $(ns[d + 1])</text>\n""")
    end
    print(io, """<text x="10" y="60" fill="#555">Synthetic data. Bar height = number of rows in the bin (not a share).</text>\n""")
    for b in 1:nb, d in 0:1
        c = counts[d + 1, b]
        bx = left + (b - 1) * binw + 3 + d * 15
        print(io, """<rect x="$bx" y="$(_f(yv(c)))" width="14" height="$(_f(top + ploth - yv(c)))" fill="$(colors[d + 1])"><title>$(edges[b])–$(edges[b + 1]): $c</title></rect>\n""")
    end
    for b in 1:(nb + 1)
        print(io, """<text x="$(left + (b - 1) * binw)" y="$(top + ploth + 16)" text-anchor="middle" fill="#555">$(edges[b])</text>\n""")
    end
    print(io, """<line x1="$left" y1="$(top + ploth)" x2="$(left + binw * nb)" y2="$(top + ploth)" stroke="#333"/>\n""")
    print(io, """<text x="$left" y="$(top - 8)" fill="#555">tallest bar = $ymax rows</text>\n""")
    print(io, """<text x="$(left + binw * nb ÷ 2)" y="$(top + ploth + 36)" text-anchor="middle">$(_esc(String(col)))</text>\n""")
    print(io, "</svg>\n")
    return String(take!(io))
end

end # module
