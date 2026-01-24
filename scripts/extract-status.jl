# Extract status from all course materials and write to _status.yml
# Run with: julia --project=scripts scripts/extract-status.jl

using Pkg
Pkg.instantiate()

using YAML

function extract_frontmatter(filepath::String)
    content = read(filepath, String)
    m = match(r"^---\n(.*?)\n---"s, content)
    isnothing(m) && return Dict{String,Any}()
    try
        return YAML.load(m.captures[1])
    catch e
        @warn "Failed to parse YAML in $filepath: $e"
        return Dict{String,Any}()
    end
end

function main()
    # Initialize status dictionaries
    status = Dict{String,Dict{String,String}}(
        "lectures" => Dict{String,String}(),
        "labs" => Dict{String,String}(),
        "readings" => Dict{String,String}(),
        "assignments" => Dict{String,String}()
    )

    # Lectures (weeks 1-13)
    for week in 1:13
        id = "week-" * lpad(week, 2, '0')
        path = joinpath("lectures", id, "index.qmd")
        if isfile(path)
            fm = extract_frontmatter(path)
            status["lectures"][id] = get(fm, "status", "draft")
        end
    end

    # Labs (1-11, with semester suffix)
    for lab in 1:11
        id = "lab-" * lpad(lab, 2, '0') * "-S26"
        path = joinpath("labs", id, "index.qmd")
        if isfile(path)
            fm = extract_frontmatter(path)
            status["labs"][id] = get(fm, "status", "draft")
        end
    end

    # Readings (weeks 1-14)
    for week in 1:14
        id = "week-" * lpad(week, 2, '0')
        path = joinpath("readings", id * "-reading.qmd")
        if isfile(path)
            fm = extract_frontmatter(path)
            status["readings"][id] = get(fm, "status", "draft")
        end
    end

    # Final project assignments
    assignment_files = [
        ("topic-proposal", "assignments/final-project/topic-proposal.qmd"),
        ("memo-1", "assignments/final-project/memo-1-framework.qmd"),
        ("memo-2", "assignments/final-project/memo-2-evidence.qmd"),
        ("memo-3", "assignments/final-project/memo-3-robustness.qmd"),
        ("slides", "assignments/final-project/executive-briefing.qmd"),
        ("presentations", "assignments/final-project/executive-briefing.qmd"),
        ("written-report", "assignments/final-project/written-report.qmd"),
        ("final-project", "assignments/final-project/index.qmd")
    ]
    for (id, path) in assignment_files
        if isfile(path)
            fm = extract_frontmatter(path)
            # Check both "status" and "draft" fields for compatibility
            if haskey(fm, "status")
                status["assignments"][id] = fm["status"]
            elseif get(fm, "draft", false) == true
                status["assignments"][id] = "draft"
            else
                status["assignments"][id] = "published"
            end
        end
    end

    # Write status registry
    YAML.write_file("_status.yml", status)
    println("✓ Status registry written to _status.yml")

    # Summary
    for (category, items) in status
        published = count(v -> v == "published", values(items))
        total = length(items)
        println("  $category: $published/$total published")
    end
end

main()
