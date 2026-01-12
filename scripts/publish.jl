# scripts/publish.jl
# Sanitizes and copies content from private repo to public repos

using Pkg
Pkg.activate(".")

# Configuration
const INSTRUCTOR_DIV_START = r"^\s*::: \{\.instructor\}"
const DIV_END = r"^\s*:::"
const SOLUTION_TAG = r"# SOLUTION"
const INSTRUCTOR_TAG = r"# INSTRUCTOR"

const PUBLIC_SITE = joinpath("..", "ceve-421-521.github.io")

# Files/folders to preserve when cleaning target directory
const PROTECTED_ITEMS = Set([".git", ".gitmodules", ".quarto", "_site", "_freeze", ".nojekyll", "pull-submodules.sh", "labs"])

# File extensions that are build artifacts (should not be copied)
const BUILD_ARTIFACTS = Set([".html", ".pdf", ".typ", ".docx", ".ipynb", ".tex", ".aux", ".log", ".out", ".fls", ".fdb_latexmk", ".synctex.gz"])

function is_build_artifact(filename::String)::Bool
    for ext in BUILD_ARTIFACTS
        if endswith(filename, ext)
            return true
        end
    end
    return false
end

function clean_target_dir(target_dir::String)
    if !isdir(target_dir)
        return
    end
    for item in readdir(target_dir)
        if item in PROTECTED_ITEMS
            continue
        end
        path = joinpath(target_dir, item)
        rm(path; recursive=true, force=true)
    end
    println("🧹 Cleaned $target_dir (preserved: $(join(PROTECTED_ITEMS, ", ")))")
end

function sanitize_content(content::String)::String
    lines = split(content, '\n')
    output_lines = String[]
    is_inside_instructor_block = false
    is_inside_solution_block = false

    for line in lines
        # Handle Instructor Div Blocks
        if occursin(INSTRUCTOR_DIV_START, line)
            is_inside_instructor_block = true
            continue
        end

        if is_inside_instructor_block && occursin(DIV_END, line)
            is_inside_instructor_block = false
            continue
        end

        if is_inside_instructor_block
            continue
        end

        # Handle Solution Blocks - remove all code from # SOLUTION until code block ends
        if occursin(SOLUTION_TAG, line) || occursin(INSTRUCTOR_TAG, line)
            is_inside_solution_block = true
            push!(output_lines, "# Your code here")
            continue
        end

        # Exit solution block when code block ends
        if is_inside_solution_block && occursin(r"^```", line)
            is_inside_solution_block = false
            push!(output_lines, line)
            continue
        end

        # Skip lines inside solution block
        if is_inside_solution_block
            continue
        end

        push!(output_lines, line)
    end

    return join(output_lines, '\n')
end

function sanitize_file(source_path::String, target_path::String)
    if !isfile(source_path)
        error("Source file not found: $source_path")
    end

    content = read(source_path, String)
    sanitized = sanitize_content(content)

    mkpath(dirname(target_path))
    write(target_path, sanitized)
    println("✅ Sanitized: $target_path")
end

function copy_file(source_path::String, target_path::String)
    if !isfile(source_path)
        return false
    end
    mkpath(dirname(target_path))
    cp(source_path, target_path; force=true)
    println("✅ Copied: $target_path")
    return true
end

function copy_dir(source_dir::String, target_dir::String; exclude=[])
    if !isdir(source_dir)
        return false
    end
    for item in readdir(source_dir)
        if item in exclude || startswith(item, ".")
            continue
        end
        src = joinpath(source_dir, item)
        dst = joinpath(target_dir, item)
        if isdir(src)
            cp(src, dst; force=true)
        else
            mkpath(dirname(dst))
            cp(src, dst; force=true)
        end
    end
    println("✅ Copied directory: $target_dir")
    return true
end

function publish_lab(lab_num::String, semester::String="S26")
    lab_id = length(lab_num) == 1 ? "0$lab_num" : lab_num
    src_dir = joinpath("labs", "lab-$lab_id-$semester")
    target_dir = joinpath("..", "lab-$lab_id-$semester")

    if !isdir(src_dir)
        println("❌ Source not found: $src_dir")
        return
    end

    if !isdir(target_dir)
        println("⚠️  Target repo not found at $target_dir")
        println("   Please create it first.")
        return
    end

    # Sanitize index.qmd
    sanitize_file(joinpath(src_dir, "index.qmd"), joinpath(target_dir, "index.qmd"))

    # Copy supporting files
    for filename in ["Project.toml", "README.md", ".gitignore"]
        copy_file(joinpath(src_dir, filename), joinpath(target_dir, filename))
    end

    # Copy data directory
    src_data = joinpath(src_dir, "data")
    if isdir(src_data)
        cp(src_data, joinpath(target_dir, "data"); force=true)
        println("✅ Copied data/")
    end

    # Copy _assets directory (for custom SCSS)
    src_assets = joinpath(src_dir, "_assets")
    if isdir(src_assets)
        dst_assets = joinpath(target_dir, "_assets")
        rm(dst_assets; recursive=true, force=true)
        cp(src_assets, dst_assets)
        println("✅ Copied _assets/")
    end

    println("\n📦 Lab $lab_id published to $target_dir")
end

function publish_site()
    if !isdir(PUBLIC_SITE)
        println("❌ Public site not found at $PUBLIC_SITE")
        return
    end

    println("🚀 Publishing to $PUBLIC_SITE\n")

    # Run status extraction first
    println("📊 Extracting material status...")
    run(`julia --project=scripts scripts/extract-status.jl`)
    println()

    # Clean target directory first (removes stale files)
    clean_target_dir(PUBLIC_SITE)

    # Copy config files (no sanitization needed)
    for config in ["_quarto.yml", "_variables.yml", ".gitignore", "mathjax-config.html", "references.bib", "_status.yml"]
        if isfile(config)
            copy_file(config, joinpath(PUBLIC_SITE, config))
        end
    end

    # Copy scripts directory (needed for pre-render)
    if isdir("scripts")
        dst_scripts = joinpath(PUBLIC_SITE, "scripts")
        rm(dst_scripts; recursive=true, force=true)
        cp("scripts", dst_scripts)
        println("✅ Copied scripts/")
    end

    # Copy directories needed for build
    for dir in ["_assets", "_extensions"]
        if isdir(dir)
            dst = joinpath(PUBLIC_SITE, dir)
            rm(dst; recursive=true, force=true)
            cp(dir, dst)
            println("✅ Copied $dir/")
        end
    end

    # Sanitize all root .qmd files
    for item in readdir(".")
        if isfile(item) && endswith(item, ".qmd")
            sanitize_file(item, joinpath(PUBLIC_SITE, item))
        end
    end

    # Sanitize lectures (week by week)
    if isdir("lectures")
        for week_dir in readdir("lectures")
            src_week = joinpath("lectures", week_dir)
            if !isdir(src_week)
                continue
            end
            for item in readdir(src_week)
                src_path = joinpath(src_week, item)
                dst_path = joinpath(PUBLIC_SITE, "lectures", week_dir, item)
                if isfile(src_path)
                    # Skip all lesson_plan files (instructor-only)
                    if startswith(item, "lesson_plan")
                        continue
                    end
                    # Skip build artifacts (.html, .pdf, etc.)
                    if is_build_artifact(item)
                        continue
                    end
                    if endswith(item, ".qmd")
                        sanitize_file(src_path, dst_path)
                    else
                        # Copy images and other assets directly
                        copy_file(src_path, dst_path)
                    end
                end
            end
        end
        println("✅ Lectures synced")
    end

    # Sanitize readings
    if isdir("readings")
        for item in readdir("readings")
            src_path = joinpath("readings", item)
            dst_path = joinpath(PUBLIC_SITE, "readings", item)
            if isfile(src_path) && endswith(item, ".qmd")
                sanitize_file(src_path, dst_path)
            end
        end
        println("✅ Readings synced")
    end

    # Sanitize assignments
    if isdir("assignments")
        for item in readdir("assignments")
            src_path = joinpath("assignments", item)
            dst_path = joinpath(PUBLIC_SITE, "assignments", item)
            if isfile(src_path) && endswith(item, ".qmd")
                sanitize_file(src_path, dst_path)
            end
        end
        println("✅ Assignments synced")
    end

    println("\n🎉 Site published to $PUBLIC_SITE")
end

# CLI
if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        println("""
Usage:
  julia scripts/publish.jl lab <number> [semester]   Publish a lab to its repo
  julia scripts/publish.jl site                      Publish all content to public website
  julia scripts/publish.jl file <source> <target>    Sanitize a single file

Examples:
  julia scripts/publish.jl lab 1           # Publishes lab-01-S26
  julia scripts/publish.jl lab 1 S26       # Same as above
  julia scripts/publish.jl site            # Syncs lectures, readings, assignments to public site
""")
        exit(1)
    end

    mode = ARGS[1]

    if mode == "lab"
        if length(ARGS) < 2
            println("Error: Lab mode requires lab number")
            exit(1)
        end
        semester = length(ARGS) >= 3 ? ARGS[3] : "S26"
        publish_lab(ARGS[2], semester)

    elseif mode == "site"
        publish_site()

    elseif mode == "file"
        if length(ARGS) < 3
            println("Error: File mode requires source and target paths")
            exit(1)
        end
        sanitize_file(ARGS[2], ARGS[3])

    else
        println("Error: Unknown mode '$mode'. Use 'lab', 'site', or 'file'.")
        exit(1)
    end
end
