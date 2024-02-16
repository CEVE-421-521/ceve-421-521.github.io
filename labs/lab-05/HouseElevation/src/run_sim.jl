"""
Run the model for a given action and SOW
"""
function run_sim(a::Action, sow::SOW, p::ModelParams)

    # first, we calculate the cost of elevating the house
    construction_cost = elevation_cost(p.house, a.Δh_ft)

    # next, we calculate expected annual damages for each year
    # map is just a fancy way of writing a for loop across multiple lines
    eads = map(p.years) do year # equivalent to `for year in years`

        # calculate the sea level for this year
        slr_ft = sow.slr(year)

        # compute EAD using Monte Carlo
        storm_surges_ft = rand(sow.surge_dist, p.n_mc_samples)
        depth_ft_gauge = storm_surges_ft .+ slr_ft
        depth_ft_house = depth_ft_gauge .- (p.house.height_above_gauge_ft + a.Δh_ft)

        # calculate the expected annual damages
        damages_frac = p.house.ddf.(depth_ft_house) ./ 100 # convert to fraction
        mean(damages_frac) * p.house.value_usd # convert to USD
    end

    # finally, we aggregate the costs and benefits to get the net present value
    years_idx = p.years .- minimum(p.years) # 0, 1, 2, 3, .....
    discount_fracs = (1 - sow.discount_rate) .^ years_idx # 1, 1-r, (1-r)^2, (1-r)^3, .....
    ead_npv = sum(eads .* discount_fracs)
    return -(ead_npv + construction_cost)
end
