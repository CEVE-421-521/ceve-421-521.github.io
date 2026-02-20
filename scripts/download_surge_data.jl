#!/usr/bin/env julia

#=
Download hourly water level data from NOAA Tides and Currents API
for Sewells Point, VA (station 8638610), compute annual maxima,
and save to CSV.

This script exists for transparency so students can see where the
data in labs/lab-05-S26/data/annual_maxima.csv came from.

Reference: https://github.com/jdossgollin/2022-elevation-robustness
NOAA API docs: https://api.tidesandcurrents.noaa.gov/api/prod/
=#

using CSV
using DataFrames
using Dates
using Downloads

# Configuration
const STATION_ID = "8638610"
const STATION_NAME = "Sewells Point, VA"
const DATUM = "NAVD"
const UNITS = "metric"
const TIME_ZONE = "gmt"
const APPLICATION = "CEVE421"
const START_YEAR = 1928
const END_YEAR = year(today()) - 1  # last complete year
const OUTPUT_FILE = joinpath(@__DIR__, "..", "labs", "lab-05-S26", "data", "annual_maxima.csv")

"""
    build_url(year::Int) -> String

Construct the NOAA Tides and Currents API URL for a given year.
"""
function build_url(yr::Int)
    return "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter" *
           "?product=hourly_height" *
           "&application=$(APPLICATION)" *
           "&station=$(STATION_ID)" *
           "&begin_date=$(yr)0101" *
           "&end_date=$(yr)1231" *
           "&datum=$(DATUM)" *
           "&units=$(UNITS)" *
           "&time_zone=$(TIME_ZONE)" *
           "&format=csv"
end

"""
    download_year(year::Int) -> Union{DataFrame, Nothing}

Download hourly water level data for a single year.
Returns a DataFrame or `nothing` if no data is available.
"""
function download_year(yr::Int)
    url = build_url(yr)
    local raw_text
    try
        io = IOBuffer()
        Downloads.download(url, io)
        raw_text = String(take!(io))
    catch e
        @warn "Failed to download data for $(yr): $(e)"
        return nothing
    end

    # Check for error responses from the API
    if occursin("Error", raw_text) && occursin("No data was found", raw_text)
        return nothing
    end

    # Parse CSV -- column names have leading spaces except "Date Time"
    df = CSV.read(IOBuffer(raw_text), DataFrame)

    # The water level column has a leading space: " Water Level"
    wl_col = " Water Level"
    if !hasproperty(df, wl_col)
        @warn "Year $(yr): Water Level column not found. Columns: $(names(df))"
        return nothing
    end

    # Select and rename columns
    result = select(df, "Date Time" => :datetime, wl_col => :water_level_m)

    # Drop rows with missing water levels
    dropmissing!(result, :water_level_m)

    if nrow(result) == 0
        return nothing
    end

    return result
end

"""
    compute_annual_maxima(start_year, end_year) -> DataFrame

Download hourly data year by year, compute annual maximum water level,
and return a DataFrame with columns `year` and `annual_max_m`.
"""
function compute_annual_maxima(start_year::Int, end_year::Int)
    years = Int[]
    maxima = Float64[]

    for yr in start_year:end_year
        print("Downloading $(yr)... ")
        df = download_year(yr)
        if df === nothing
            println("no data")
            continue
        end
        max_wl = maximum(df.water_level_m)
        push!(years, yr)
        push!(maxima, max_wl)
        println("$(nrow(df)) observations, max = $(round(max_wl; digits=3)) m")

        # Be polite to the API
        sleep(0.25)
    end

    return DataFrame(; year=years, annual_max_m=maxima)
end

function main()
    println("=" ^ 60)
    println("NOAA Tides & Currents: Annual Maximum Water Level")
    println("Station: $(STATION_ID) ($(STATION_NAME))")
    println("Datum: $(DATUM), Units: $(UNITS)")
    println("Years: $(START_YEAR) to $(END_YEAR)")
    println("=" ^ 60)
    println()

    result = compute_annual_maxima(START_YEAR, END_YEAR)

    println()
    println("-" ^ 60)
    println("Downloaded $(nrow(result)) years of annual maxima")
    println("Year range: $(minimum(result.year)) to $(maximum(result.year))")
    println("Max water level range: $(round(minimum(result.annual_max_m); digits=3)) m to $(round(maximum(result.annual_max_m); digits=3)) m")
    println()

    # Ensure output directory exists
    mkpath(dirname(OUTPUT_FILE))

    # Write to CSV
    CSV.write(OUTPUT_FILE, result)
    println("Saved to: $(OUTPUT_FILE)")
    println()

    # Show first and last few rows
    println("First 5 rows:")
    println(first(result, 5))
    println()
    println("Last 5 rows:")
    println(last(result, 5))
end

main()
