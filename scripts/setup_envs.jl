#!/usr/bin/env julia

#=
Unified script for managing lab Julia environments.

Usage:
  julia scripts/setup_labs.jl              # resolve all lab environments (default)
  julia scripts/setup_labs.jl resolve      # same as above
  julia scripts/setup_labs.jl fix-qmd      # rewrite Pkg setup blocks in lab index.qmd files

The `resolve` command:
  - Activates each lab environment
  - Removes GitHub-hosted packages (ICOW, SimOptDecisions) if present
  - Resolves the environment for the current Julia version
  - Re-adds the GitHub packages
  - Precompiles all packages
  - On failure, deletes Manifest.toml and instantiates from scratch

The `fix-qmd` command:
  - Rewrites old-style Pkg setup code cells in each lab's index.qmd
    to a robust try/catch pattern that handles missing Manifests
=#

using Pkg
using Logging

const BASE_DIR = dirname(@__DIR__)
const LABS_DIR = joinpath(BASE_DIR, "labs")

const GITHUB_PACKAGES = [
    PackageSpec(; url="https://github.com/dossgollin-lab/ICOW.jl"),
    PackageSpec(; url="https://github.com/dossgollin-lab/SimOptDecisions"),
]
const GITHUB_PACKAGE_NAMES = ["ICOW", "SimOptDecisions"]

"""Find all lab directories matching lab-NN-SNN pattern."""
function find_lab_dirs()
    dirs = filter(readdir(LABS_DIR; join=true)) do path
        isdir(path) && occursin(r"lab-\d+-S\d+", basename(path))
    end
    return sort(dirs)
end

# ---------------------------------------------------------------------------- #
#                              resolve command                                  #
# ---------------------------------------------------------------------------- #

function resolve_env(env_dir::String)
    env_name = basename(env_dir)
    project_file = joinpath(env_dir, "Project.toml")
    manifest_file = joinpath(env_dir, "Manifest.toml")

    if !isfile(project_file)
        @warn "No Project.toml in $env_name, skipping"
        return
    end

    println("\n=== $env_name ===")
    Pkg.activate(env_dir)

    # figure out which GitHub packages this env uses
    proj_deps = keys(Pkg.project().dependencies)
    gh_present = filter(name -> name in proj_deps, GITHUB_PACKAGE_NAMES)

    # remove GitHub packages before resolving (avoids version conflicts)
    if !isempty(gh_present)
        println("  Removing: ", join(gh_present, ", "))
        Pkg.rm(gh_present)
    end

    # resolve for the current Julia version
    println("  Resolving...")
    Pkg.resolve()

    # re-add GitHub packages
    if !isempty(gh_present)
        to_add = [p for p in GITHUB_PACKAGES if any(occursin(n, p.url) for n in gh_present)]
        println("  Re-adding: ", join(gh_present, ", "))
        Pkg.add(to_add)
    end

    # precompile to catch issues early
    println("  Precompiling...")
    Pkg.precompile()

    println("  Done.")
end

function resolve_env_with_recovery(env_dir::String)
    try
        resolve_env(env_dir)
    catch e
        env_name = basename(env_dir)
        @error "Failed to resolve $env_name" exception = e

        manifest_file = joinpath(env_dir, "Manifest.toml")
        @warn "Attempting recovery: deleting Manifest.toml and reinstantiating..."
        try
            Pkg.activate(env_dir)
            isfile(manifest_file) && rm(manifest_file)
            Pkg.instantiate()
            Pkg.precompile()
            println("  Recovery succeeded for $env_name")
        catch recovery_error
            @error "Recovery failed for $env_name" exception = recovery_error
        end
    end
end

function cmd_resolve()
    lab_dirs = find_lab_dirs()
    println("Found $(length(lab_dirs)) lab directories")
    println("Julia version: $(VERSION)")
    println("="^50)

    # resolve the base directory first
    println("\n--- Base environment ---")
    resolve_env_with_recovery(BASE_DIR)

    # resolve each lab environment
    for lab_dir in lab_dirs
        resolve_env_with_recovery(lab_dir)
    end

    Pkg.activate(BASE_DIR)
    println("\n" * "="^50)
    println("Environment setup complete. Returned to base environment.")
end

# ---------------------------------------------------------------------------- #
#                              fix-qmd command                                  #
# ---------------------------------------------------------------------------- #

const NEW_SETUP_CODE = """```{julia}
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

# Old patterns that may appear in lab qmd files
const QMD_PATTERNS = [
    # Pattern 1: Simple if !isfile (two variants)
    r"```\{julia\}\s*\n#\| output: false\s*\n(?:if !isfile\(\"Manifest\.toml\"\)\s*\n\s*using Pkg\s*\n\s*Pkg\.instantiate\(\)\s*\nend|using Pkg\s*\nif !isfile\(\"Manifest\.toml\"\)\s*\n\s*Pkg\.instantiate\(\)\s*\nend)\s*\n```",
    # Pattern 2: dir_name with Pkg.activate
    r"```\{julia\}\s*\n#\| output: false\s*\ndir_name = dirname\(@__FILE__\)\s*\nusing Pkg\s*\nPkg\.activate\(dir_name\)(?:\s*#[^\n]*)?\s*\nif !isfile\(joinpath\(dir_name, \"Manifest\.toml\"\)\)\s*\n\s*Pkg\.instantiate\(\)\s*\nend\s*\n```",
]

function cmd_fix_qmd()
    lab_dirs = find_lab_dirs()
    lab_files = String[]
    for lab_dir in lab_dirs
        index_file = joinpath(lab_dir, "index.qmd")
        isfile(index_file) && push!(lab_files, index_file)
    end

    println("Found $(length(lab_files)) lab index.qmd files")
    println("="^50)

    for file in lab_files
        lab_name = basename(dirname(file))
        println("\nProcessing: $lab_name")

        content = read(file, String)
        original = content

        for (i, pattern) in enumerate(QMD_PATTERNS)
            if occursin(pattern, content)
                content = replace(content, pattern => NEW_SETUP_CODE)
                println("  Replaced pattern $i")
            end
        end

        if content != original
            write(file, content)
            println("  File updated.")
        else
            println("  No changes needed.")
        end
    end

    println("\n" * "="^50)
    println("QMD fix complete.")
end

# ---------------------------------------------------------------------------- #
#                                    CLI                                        #
# ---------------------------------------------------------------------------- #

function main()
    cmd = length(ARGS) >= 1 ? ARGS[1] : "resolve"

    if cmd == "resolve"
        cmd_resolve()
    elseif cmd == "fix-qmd"
        cmd_fix_qmd()
    else
        println("""
Usage:
  julia scripts/setup_labs.jl              Resolve all lab environments (default)
  julia scripts/setup_labs.jl resolve      Same as above
  julia scripts/setup_labs.jl fix-qmd      Rewrite Pkg setup blocks in lab index.qmd files
""")
        exit(1)
    end
end

main()
