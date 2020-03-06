#####################################
#
# How to make a ragged array for JAGS
#  using nested indexing
#
# Written by M. Fidino 2020-03-06 ymd
#
#####################################

library(runjags)
library(mcmcplots)

# Step 1. Simulate some occupancy data

set.seed(-132)

# number of sites and repeat surveys
nsite <- 500
nrep <- 20

# design matrix for occupancy
X_occupancy <- cbind(
  1,
  rnorm(nsite)
)

# occpuancy parameters, intercept and slope
b_occupancy <- c(
  0.73,
  -1
)

# log-odds of occupancy
logit_prob_occupancy <- X_occupancy %*% b_occupancy

# convert to probability
prob_occupancy <- plogis(
  logit_prob_occupancy
)

# True occurence
z <- rbinom(
  nsite,
  1,
  prob_occupancy
)

# Step 2. Add imperfect detection

# design matrix for detection. Assuming
#  that there are observation specific
#  covariates. Site x n parameter x repeat visits
X_detection <- array(
  rnorm(nsite*2*nrep),
  dim = c(nsite, 2, nrep)
)

# convert the first column to 1's for the intercept
X_detection[,1,] <- 1

# detection parameters, intercept and slope
b_detection <- c(
  1,
  -0.5
)

# log odds of detection
logit_prob_detection <- apply(
  X_detection,
  3,
  function(x) x %*% b_detection
)


# probability of detection
prob_detection <- plogis(
  logit_prob_detection
)

# simulate the detection/ non-detection data
y <- matrix(
  rbinom(
    nsite*nrep,
    1,
    sweep(prob_detection, 1, z, "*")
  ),
  ncol = nrep,
  nrow = nsite
)

# Step 3. Lose some of the data. Here we are going to
#  assume that sampling is unequal across sites, and therefore
#  each site will have a different number of repeat visits.
#  We are going to simualte the number of samples per site
#  and then randomly input NA's into the y matrix.

samps_per_site <- sample(
  5:nrep,
  nsite,
  replace = TRUE
)

# just going to loop through and input NA's
y_na <- y
for(i in 1:nsite){
  to_na <- sample(
    1:nrep,
    nrep - samps_per_site[i],
    replace = FALSE
  )
  y_na[i, to_na] <- NA
}

# Step 4. Determine where we have data.
#  If we just used y, we would be inputting a nsite*nrep
#  matrix with a LOT of NA's. We can reduce this.

has_data <- which(
  !is.na(y_na),
  arr.ind = TRUE
)

# the row ID tells us which site we have,
#  the col ID tells us which observation. We
#  can use this information to collect the
#  appropriate observation covariates

# ob cov long will hold the covariate values for each
#  observation that we have data in long format
ob_cov_long <- matrix(
  1,
  nrow(has_data),
  ncol = 2
)

for(i in 1:nrow(has_data)){
  ob_cov_long[i,2] <- X_detection[
    has_data[i,1],
    2,
    has_data[i,2]
  ]
}

# We need to make the detection matrix long format as well.
#  We need this to have the same ordering as has_data.
y_long <- y_na[!is.na(y_na)]

# Step 5. Analyze model.We are going to
#  analyze the detection data in long format
#  while the occupancy data will be in the standard
#  format we are used to.

# set up data list
data_list <- list(
  y = y_long,
  site_id = has_data[,1],
  X_occ = X_occupancy,
  X_det = ob_cov_long,
  nsite = nsite,
  nvisits = length(y_long)
)



z_init <- rowSums(y_na, na.rm = TRUE)
z_init[z_init > 1] <- 1

inits_list <- list(z = z_init)

m1 <- run.jags(
  model = "ragged_occupancy.R",
  data = data_list,
  n.chains = 3,
  monitor = c("B_occ", "B_det"),
  adapt = 1000,
  burnin = 2000,
  sample = 5000,
  thin = 1,
  inits = inits_list,
 summarise = FALSE,
 modules = "glm"
)

# plot out the results
jpeg("model_output.jpeg")
caterplot(m1)
points(
  y = c(3,1,4,2),
  x = c(b_occupancy, b_detection),
  pch = 19
)
legend("topleft",
       c("Estimate", "Truth"),
       pch = 19,
       col = c(mcmcplotsPalette(1), "black")
       )
dev.off()
