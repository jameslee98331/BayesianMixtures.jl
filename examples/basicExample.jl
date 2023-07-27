# A basic example of using the BayesianMixtures package.
using BayesianMixtures
using Printf

B = BayesianMixtures

# Simulate some data
x = randn(5000)

# Specify model, data, and MCMC options
n_total = 10000  # total number of MCMC sweeps to run
options = B.options("Normal", "MFM", x, n_total)  # MFM model with univariate Normal components

# Run MCMC sampler
result = B.run_sampler(options)

# Display the posterior on k (number of components)
println("Posterior on k:")
for (k, pk) in enumerate(B.k_posterior(result; upto=10))
    @printf "%d: %.3g\n" k pk
end


