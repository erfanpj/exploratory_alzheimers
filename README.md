# Alzheimer's Data Analysis in Julia

## Overview
This small project analyzes Alzheimer's disease data using Julia. It performs data cleaning, sorting, filtering, and statistical analysis to provide insights into the relationship between Alzheimer's cases and various factors such as age, gender, smoking, and diabetes.

## Features
- Loads and cleans Alzheimer's disease dataset (`alzheimers_disease_data.csv`).
- Filters and sorts data based on key parameters.
- Counts Alzheimer's cases based on diabetes status.
- Analyzes gender and smoking distribution among Alzheimer's patients.
- Computes age statistics (mean, median, standard deviation, min, max).
- Uses `PrettyTables.jl` for formatted data display.

## Dependencies
To run this project, you need the following Julia packages:
```julia
using Pkg
Pkg.add(["CSV", "DataFrames", "Statistics", "PrettyTables"])
