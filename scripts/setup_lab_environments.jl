#!/usr/bin/env julia

"""
Setup script to ensure all lab environments are properly configured.
Run this script to instantiate or resolve all lab project environments.
"""

using Pkg
using Logging

# Get the base directory
base_dir = dirname(@__DIR__)
labs_dir = joinpath(base_dir, "labs")

# Find all lab directories
lab_dirs = filter(readdir(labs_dir; join=true)) do path
    isdir(path) && occursin(r"lab-\d+-S\d+", basename(path))
end

println("Found $(length(lab_dirs)) lab directories")
println("=" ^ 50)

# Process each lab directory
for lab_dir in lab_dirs
    lab_name = basename(lab_dir)
    println("\nProcessing: $lab_name")
    println("-" ^ 30)

    project_file = joinpath(lab_dir, "Project.toml")
    manifest_file = joinpath(lab_dir, "Manifest.toml")

    if !isfile(project_file)
        @warn "No Project.toml found in $lab_name, skipping..."
        continue
    end

    try
        # Activate the project
        Pkg.activate(lab_dir)

        # Check if we need to instantiate or just resolve
        if !isfile(manifest_file)
            @info "No Manifest.toml found, instantiating $lab_name..."
            Pkg.instantiate()
            @info "✓ Successfully instantiated $lab_name"
        else
            # Try to resolve to ensure consistency
            @info "Manifest.toml exists, resolving $lab_name..."
            Pkg.resolve()

            # Update packages to ensure everything is current
            @info "Updating packages for $lab_name..."
            Pkg.update()

            @info "✓ Successfully resolved and updated $lab_name"
        end

        # Precompile to catch any issues early
        @info "Precompiling packages for $lab_name..."
        Pkg.precompile()
        @info "✓ Successfully precompiled $lab_name"

    catch e
        @error "Failed to process $lab_name" exception=e

        # Try recovery
        @warn "Attempting recovery for $lab_name..."
        try
            Pkg.activate(lab_dir)

            # Remove manifest and try fresh instantiation
            if isfile(manifest_file)
                rm(manifest_file)
                @info "Removed old Manifest.toml"
            end

            Pkg.instantiate()
            Pkg.precompile()
            @info "✓ Recovery successful for $lab_name"
        catch recovery_error
            @error "Recovery failed for $lab_name" exception=recovery_error
        end
    end
end

# Return to base environment
Pkg.activate(base_dir)
println("\n" * "=" ^ 50)
println("Environment setup complete!")
println("Returned to base environment: $base_dir")