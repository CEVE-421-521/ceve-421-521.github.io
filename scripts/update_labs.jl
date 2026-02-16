using Pkg

base = joinpath(@__DIR__, "..", "labs")
labs = sort(filter(d -> occursin(r"lab-\d+-S26", d), readdir(base)))

gh_pkgs = [
    PackageSpec(; url="https://github.com/dossgollin-lab/ICOW.jl"),
    PackageSpec(; url="https://github.com/dossgollin-lab/SimOptDecisions"),
]

for lab in labs
    dir = joinpath(base, lab)
    println("\n=== $lab ===")
    Pkg.activate(dir)

    # remove GitHub packages if present
    proj = Pkg.project().dependencies
    to_rm = filter(p -> p in keys(proj), ["ICOW", "SimOptDecisions"])
    if !isempty(to_rm)
        println("  Removing: ", join(to_rm, ", "))
        Pkg.rm(to_rm)
    end

    # resolve for new Julia version
    println("  Resolving...")
    Pkg.resolve()

    # re-add GitHub packages
    if !isempty(to_rm)
        to_add = [p for p in gh_pkgs if any(occursin(n, p.url) for n in to_rm)]
        println("  Re-adding: ", join(to_rm, ", "))
        Pkg.add(to_add)
    end
end
