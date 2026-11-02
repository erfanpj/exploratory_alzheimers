using Test, DataFrames, CSV
include(joinpath(@__DIR__, "..", "src", "AlzheimersEDA.jl"))
using .AlzheimersEDA

const DATA = joinpath(@__DIR__, "..", "alzheimers_disease_data.csv")
toy() = DataFrame(PatientID = [1, 2, 3, 3, 4, 5], Age = [65, 72, 80, 80, 90, 61], Gender = [0, 1, 1, 1, 0, 1],
                  Smoking = [0, 1, 0, 0, 1, 0], Diabetes = [0, 0, 1, 1, 0, 1], Depression = [0, 0, 0, 0, 1, 0],
                  Diagnosis = [1, 0, 1, 1, 1, 0])

@testset "cleaning counts" begin
    df = toy()
    allowmissing!(df)
    df.Age[6] = missing
    clean, r = clean_data(df)
    @test r == (rows_in = 6, removed_missing = 1, removed_duplicates = 1, duplicate_patient_ids = 0,
                removed_invalid_codes = 0, rows_out = 4)
    @test names(clean) == string.(MAIN_COLUMNS)
    @test nrow(df) == 6                                   # input untouched
    bad = toy(); bad.Gender[1] = 7; bad.Age[2] = 150
    c2, r2 = clean_data(bad)
    @test r2.removed_invalid_codes == 2 && r2.rows_out == 3
end

@testset "invalid and empty selections" begin
    clean, _ = clean_data(toy())
    @test nrow(select_rows(clean; min_age = 95)) == 0
    @test nrow(select_rows(clean; min_age = 70)) == 3       # strictly greater than 70
    @test_throws ArgumentError select_rows(clean; min_age = "70")
    @test_throws ArgumentError select_rows(clean; min_age = NaN)
    @test_throws ArgumentError select_rows(clean; min_age = 80, max_age = 70)
    @test_throws ArgumentError select_rows(clean; diagnosis = 2)
    empty = select_rows(clean; min_age = 95)
    s = age_summary(empty)
    @test s.Value[1] == 0 && all(ismissing, s.Value[2:end])
    @test nrow(count_by(empty, :Gender)) == 0
    one = select_rows(clean; min_age = 85)
    @test ismissing(age_summary(one).Value[4])               # no std dev for one row
end

@testset "labels and denominators" begin
    @test label_codes(:Gender, [0, 1]) == ["Male", "Female"]
    @test_throws ArgumentError label_codes(:Gender, [2])
    @test_throws ArgumentError label_codes(:Age, [70])
    c = count_by(clean_data(toy())[1], :Smoking)
    @test c.group == ["No", "Yes"] && c.count == [3, 2] && all(c.denominator .== 5) && sum(c.share) ≈ 1
end

@testset "loading errors" begin
    @test_throws ArgumentError load_data("does-not-exist.csv")
    tmp = tempname() * ".csv"
    CSV.write(tmp, select(toy(), Not(:Diagnosis)))
    @test_throws ArgumentError load_data(tmp)
end

@testset "real file: validation and the original script's numbers" begin
    raw = load_data(DATA)
    @test nrow(raw) == 2149 && ncol(raw) == 35
    v = validate_data(raw)
    @test sum(v.n_missing) == 0 && sum(v.n_invalid) == 0
    clean, r = clean_data(raw)
    @test r == (rows_in = 2149, removed_missing = 0, removed_duplicates = 0, duplicate_patient_ids = 0,
                removed_invalid_codes = 0, rows_out = 2149)
    cases = select_rows(clean; diagnosis = 1)
    # Values printed by the original script at commit b5b0057 (evidence of unchanged behaviour).
    @test nrow(cases) == 760
    @test count_by(cases, :Diabetes).count == [657, 103]
    @test count_by(cases, :Gender).count == [386, 374]
    @test count_by(cases, :Smoking).count == [543, 217]
    a = age_summary(cases)
    @test round(a.Value[2]; digits = 4) == 74.8421 && a.Value[3] == 75 && round(a.Value[4]; digits = 5) == 9.14998
    @test a.Value[5] == 60 && a.Value[6] == 90
end

@testset "E2.03 intervals, bands and figures" begin
    # Wilson reference values (k=0,n=10 and k=5,n=10), checked against the closed form.
    lo, hi = wilson_ci(0, 10); @test lo == 0 && isapprox(hi, 0.2775; atol = 1e-4)
    lo, hi = wilson_ci(5, 10); @test isapprox(lo, 0.2366; atol = 1e-4) && isapprox(hi, 0.7634; atol = 1e-4)
    @test all(ismissing, wilson_ci(0, 0))
    @test_throws ArgumentError wilson_ci(3, 2)
    @test age_band(60) == "60–64" && age_band(84) == "80–84" && age_band(85) == "85–90" && age_band(90) == "85–90"
    @test_throws ArgumentError age_band(59)
    toy = DataFrame(Age = [60, 61, 70, 90], Smoking = [0, 0, 1, 1], Diagnosis = [1, 0, 0, 1])
    p = prevalence_by(toy, :Smoking)
    @test p.group == ["No", "Yes"] && p.n == [2, 2] && p.cases == [1, 1] && all(p.ci95_low .<= p.proportion .<= p.ci95_high)
    @test sum(prevalence_by(toy, :AgeBand).n) == 4
    @test nrow(prevalence_by(toy[1:0, :], :Smoking)) == 0
    svg = svg_prevalence(p, "toy <test>")
    @test startswith(svg, "<svg") && occursin("(1/2)", svg) && occursin("toy &lt;test&gt;", svg)
    toy.MMSE = [0.0, 29.9, 30.0, 15.0]
    h = svg_histogram(toy, :MMSE, collect(0:3:30), "toy")
    @test occursin("n = 2", h) && occursin("27–30: 2", h)   # 29.9 and 30.0 both land in the last bin
end

@testset "real file: E2.03 tables" begin
    raw = load_data(joinpath(@__DIR__, "..", "alzheimers_disease_data.csv"))
    full, rep = clean_data(raw; columns = ANALYSIS_COLUMNS)
    @test rep.rows_out == 2149
    for c in vcat([:AgeBand], PREVALENCE_COLUMNS)
        t = prevalence_by(full, c)
        @test sum(t.n) == 2149 && sum(t.cases) == 760
    end
    m = numeric_by_diagnosis(full, :MMSE)
    @test sum(m.n) == 2149 && m.n == [1389, 760]
end
