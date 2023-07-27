# Run simulations with multivariate normal mixtures to compare the MFM with the DPM.
module SimCompareDPM

using Random
using LinearAlgebra
using BayesianMixtures
B = BayesianMixtures
Theta = B.MVN.Theta

# Settings
plot_runs = true # display plots of results or not
save_runs = true # save results to file or not
save_figures = true  # save the figures to file
from_file = false # true: use existing results from file, false: run sampler to generate results
reset_random = true # reset the random number generator before each run or not
use_hyperprior = false # put hyperprior on based distribution parameters or not
n_values = [50, 100, 250, 500] #[50,100,250,1000,2500]  # sizes of data sets to simulate
model_types = ["MFM", "DPM"]
data_ID = "k = 3" # label of data distribution to simulate from (k = 3 or k = 4)
t_max = 25 # guess at an upper bound on number of clusters that will occur
reps = 1:5 # 1:5  # replications to run for each model,n pair
n_burn = 5000 # 5000
n_total = 20 * n_burn
n_keep = min(1000, n_total)
results_directory = "results-SimCompareDPM"

# Create directory for results if it doesn't exist
if !isdir(results_directory)
    mkdir(results_directory)
end
println(results_directory)

# Simulate data and run the sampler for each n, rep, model_type
if !from_file
    for n in n_values
        for rep in reps

            # Simulate from the data distribution
            if reset_random
                Random.seed!(n + rep)
            end
            if data_ID == "k = 3"
                k = 3
                d = 2
                probabilities = [0.45, 0.3, 0.25]
                angle = pi / 4
                R = [cos(angle) -sin(angle); sin(angle) cos(angle)]
                V = collect(Diagonal([2.5, 0.2]))
                theta = [Theta([4, 4], collect(Diagonal(ones(d)))),
                    Theta([7, 4], inv(R * V * R')),
                    Theta([6, 2], collect(Diagonal(1 ./ [3, 0.1])))]
                x, z = B.MVN.mixrnd(n, probabilities, theta)
                true_distribution = (k, probabilities, theta, z)
                @assert(n > 2 * d)

            elseif data_ID == "k = 4"
                k = 4
                d = 2
                probabilities = [0.44, 0.3, 0.25, 0.01]
                angle = pi / 4
                R = [cos(angle) -sin(angle); sin(angle) cos(angle)]
                V = collect(Diagonal([2.5, 0.2]))
                theta = [Theta([4, 4], collect(Diagonal(ones(d)))),
                    Theta([7, 4], inv(R * V * R')),
                    Theta([6, 2], collect(Diagonal(1 ./ [3, 0.1]))),
                    Theta([8, 11], collect(Diagonal(1 ./ [0.1, 0.1])))]
                x, z = B.MVN.mixrnd(n, probabilities, theta)
                true_distribution = (k, probabilities, theta, z)
                @assert(n > 2 * d)
            else
                error("Unknown data_ID: $data_ID")
            end

            for model_type in model_types
                # Run sampler
                if reset_random
                    Random.seed!(n + rep)
                end
                options = B.options("MVN", model_type, x, n_total;
                    n_keep=n_keep, n_burn=n_burn, use_hyperprior=use_hyperprior, t_max=t_max)
                result = B.run_sampler(options)

                # Save result to file
                if save_runs
                    B.save_result(joinpath(results_directory, "n=$n-rep=$rep-type=$model_type.jld"), result)
                end
            end
        end
    end
end

if save_runs && plot_runs
    figure_number = 0
    color_list = Any[[0.5, 1, 0.5], [0.25, 0.25, 1], [0.75, 0, 1], "y", "k"]
    marker_list = Any["s", "^", "v", "o", "*"]

    # Plot posterior on t for each n, model_type
    for model_type in model_types
        global figure_number
        B.open_figure(figure_number += 1)
        for (i_n, n) in enumerate(n_values)
            results = [B.load_result(joinpath(results_directory, "n=$n-rep=$rep-type=$model_type.jld")) for rep in reps]
            B.plot_t_posterior_average(results; color=color_list[i_n], marker=marker_list[i_n], label="n = $n")
            B.labels("$model_type posterior on t", "t (number of clusters)", "p(t|data)")
            B.PyPlot.xlim(0, 10)
            B.PyPlot.ylim(0, 1)
            B.PyPlot.legend(loc="upper right", fontsize=10, numpoints=1)
        end
        if save_figures
            B.PyPlot.savefig("simCompareDPM-t_posterior-$model_type.png", dpi=200)
        end
    end

    # Plot MFM posterior on k for each n
    for model_type in intersect(model_types, ["MFM"])
        global figure_number
        B.open_figure(figure_number += 1)
        for (i_n, n) in enumerate(n_values)
            results = [B.load_result(joinpath(results_directory, "n=$n-rep=$rep-type=$model_type.jld")) for rep in reps]
            B.plot_k_posterior_average(results; color=color_list[i_n], marker=marker_list[i_n], label="n = $n")
            B.labels("$model_type posterior on k", "k (number of components)", "p(k|data)")
            B.PyPlot.xlim(0, 10)
            B.PyPlot.ylim(0, 1)
            B.PyPlot.legend(loc="upper right", fontsize=10, numpoints=1)
        end
        if save_figures
            B.PyPlot.savefig("simCompareDPM-k_posterior-$model_type.png", dpi=200)
        end
    end

    # Plot some density estimates for each model_type
    for model_type in model_types
        for (i_n, n) in enumerate(intersect(n_values, [50, 250, 1000]))
            global figure_number
            B.open_figure(figure_number += 1; figure_size=(6, 5))
            rep = 1
            result = B.load_result(joinpath(results_directory, "n=$n-rep=$rep-type=$model_type.jld"))
            B.plot_density_estimate(result; resolution=40)
            B.labels("$model_type density estimate, n = $n")
            if save_figures
                B.PyPlot.savefig("simCompareDPM-density-$model_type-n=$n.png", dpi=200)
            end
        end
    end

    # Plot some sample clusterings for each model_type
    for model_type in model_types
        for (i_n, n) in enumerate(intersect(n_values, [250]))
            rep = 1
            indices = [800, 900, 1000]
            result = B.load_result(joinpath(results_directory, "n=$n-rep=$rep-type=$model_type.jld"))
            for index in intersect(1:n_keep, indices)
                global figure_number
                B.open_figure(figure_number += 1; figure_size=(6, 5))
                x = result.options.x
                z = result.z[:, index][:]
                B.plot_clusters(x, z; markersize=5)
                B.labels("$model_type sample clusters, n = $n, index = $index")
                if save_figures
                    B.PyPlot.savefig("simCompareDPM-clusters-$model_type-n=$n-index=$index.png", dpi=200)
                end
            end
        end
    end
end

end # module simCompareDPM

