#!/usr/bin/env julia

"""
Script to fix package setup code in all lab notebooks to be more robust.
This handles environment sync issues.
"""

using Logging

# Get the base directory
base_dir = dirname(@__DIR__)
labs_dir = joinpath(base_dir, "labs")

# The new robust setup code
new_setup_code = """```{julia}
#| output: false
using Pkg
try
    # Activate the local project
    Pkg.activate(@__DIR__)

    # Check if Manifest exists, if not instantiate
    if !isfile(joinpath(@__DIR__, "Manifest.toml"))
        Pkg.instantiate()
    else
        # Try to resolve any inconsistencies
        Pkg.resolve()
    end
catch e
    @warn "Package environment setup failed, attempting recovery" exception=e
    Pkg.activate(@__DIR__)
    Pkg.instantiate()
end
```"""

# Pattern 1: Simple if !isfile pattern (labs 1, 5-11)
pattern1_old = r"```\{julia\}\s*\n#\| output: false\s*\n(?:if !isfile\(\"Manifest\.toml\"\)\s*\n\s*using Pkg\s*\n\s*Pkg\.instantiate\(\)\s*\nend|using Pkg\s*\nif !isfile\(\"Manifest\.toml\"\)\s*\n\s*Pkg\.instantiate\(\)\s*\nend)\s*\n```"

# Pattern 2: dir_name with Pkg.activate pattern (labs 2-3)
pattern2_old = r"```\{julia\}\s*\n#\| output: false\s*\ndir_name = dirname\(@__FILE__\)\s*\nusing Pkg\s*\nPkg\.activate\(dir_name\)(?:\s*#[^\n]*)?\s*\nif !isfile\(joinpath\(dir_name, \"Manifest\.toml\"\)\)\s*\n\s*Pkg\.instantiate\(\)\s*\nend\s*\n```"

# Find all lab index.qmd files
lab_files = String[]
for entry in readdir(labs_dir; join=true)
    if isdir(entry) && occursin(r"lab-\d+-S\d+", basename(entry))
        index_file = joinpath(entry, "index.qmd")
        if isfile(index_file)
            push!(lab_files, index_file)
        end
    end
end

println("Found $(length(lab_files)) lab index.qmd files")
println("=" ^ 50)

# Process each file
for file in lab_files
    lab_name = basename(dirname(file))
    println("\nProcessing: $lab_name")

    content = read(file, String)
    original_content = content

    # Try pattern 1
    if occursin(pattern1_old, content)
        content = replace(content, pattern1_old => new_setup_code)
        println("  ✓ Replaced pattern 1 (simple if !isfile)")
    end

    # Try pattern 2
    if occursin(pattern2_old, content)
        content = replace(content, pattern2_old => new_setup_code)
        println("  ✓ Replaced pattern 2 (dir_name with Pkg.activate)")
    end

    # Write back if changed
    if content != original_content
        write(file, content)
        println("  ✓ File updated successfully")
    else
        println("  ℹ No changes needed (may already be updated or use different pattern)")
    end
end

println("\n" * "=" ^ 50)
println("Package setup fix complete!")
println("\nThe new setup code:")
println("-" ^ 30)
println(new_setup_code)