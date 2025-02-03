using CSV, DataFrames, Statistics, PrettyTables

# Load dataset
df = CSV.read("alzheimers_disease_data.csv", DataFrame)

#------------------------------------------------------------Clean Data Function-----------------------------------------------------------------------------
function clean_data!(data)
    # Handle missing values (if any)
    dropmissing!(data)
    # Define columns to keep
    main_cols = [:Age, :Gender, :Smoking,
                        :Diabetes, :Depression, :Diagnosis]
    # Remove duplicate rows
    unique!(data)
    # Select only the specified columns for final output
    select!(data, main_cols)
    return data
end
# Clean the DataFrame
cleaned_df = clean_data!(df)
#------------------------------------------------------------Sort and filter the DataFrame-----------------------------------------------------------------------------
# Sort the DataFrame
sort_df = sort!(cleaned_df, :Diagnosis, rev=true)
# Filter on Age > 70 the DataFrame
filter_df = filter(row -> row.Age > 70, cleaned_df)

# Display the cleaned table
println("Sorted clean data(First 5 rows):")
pretty_table(first(sort_df, 5))

println("First 5 Rows on age > 70:")
pretty_table(first(filter_df, 5))
#----------------------------------------------------------Alzheimer's cases by Diabetes--------------------------------------------------------------------------------
# Count Alzheimer's cases by Diabetes
alzheimers_count_diabetes= combine(groupby(filter(row -> row.Diagnosis == 1, cleaned_df), :Diabetes), 
                           nrow => :Alzheimer_Count)

# Display table
println("Alzheimer's cases by diabetes:")
pretty_table(alzheimers_count_diabetes)
#---------------------------------------------------simple data Analysis of Alzheimer's Cases--------------------------------------------------------------------
# Count Alzheimer's cases
alzheimers_count =filter(row -> row.Diagnosis == 1, cleaned_df)
                          
#Create a dictionary to convert 0 and 1 into meaningful names
gender_labels = Dict(0 => "Male", 1 => "Female")
smoking_labels = Dict(0 => "No", 1 => "Yes")

# Convert Gender and Smoking columns to readable labels
alzheimers_count.Gender = [gender_labels[g] for g in alzheimers_count.Gender]
alzheimers_count.Smoking = [smoking_labels[s] for s in alzheimers_count.Smoking]

# Compute necessary statistics for Age
age_stats = DataFrame(Statistic=["Mean", "Median", "Std Dev", "Min", "Max"], 
                      Value=[mean(alzheimers_count.Age), median(alzheimers_count.Age), 
                             std(alzheimers_count.Age), minimum(alzheimers_count.Age), 
                             maximum(alzheimers_count.Age)])


# Compute gender and smoking counts on Alzheimer's cases
gender_counts = combine(groupby(alzheimers_count, :Gender), nrow => :Count)
smoking_counts = combine(groupby(alzheimers_count, :Smoking), nrow => :Count)
#-------------------------------------------------------------------show tables----------------------------------------------------------------------------------
# Display the summary tables on Alzheimer's cases
println("Age Statistics:")
pretty_table(age_stats)

println("\nGender Distribution:")
pretty_table(gender_counts)

println("\nSmoking Distribution:")
pretty_table(smoking_counts)


