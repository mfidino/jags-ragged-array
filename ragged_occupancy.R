model{
  # priors
  B_occ[1] ~ dlogis(0,1)
  B_occ[2] ~ dlogis(0,1)
  B_det[1] ~ dlogis(0,1)
  B_det[2] ~ dlogis(0,1)
  # latent state model
  for(i in 1:nsite){
    logit(psi[i]) <- inprod(B_occ, X_occ[i,])
    z[i] ~ dbern(psi[i])
  }
  # detection model, the important part
  #  is just indexing what site the yth data point
  #  is associated to!
  for(j in 1:nvisits){
    logit(rho[j]) <- inprod(B_det, X_det[j,])
    y[j] ~ dbern(rho[j] * z[site_id[j]])
  }
}
