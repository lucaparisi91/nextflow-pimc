library(tidyverse)
library(coda)
library(tidymodels)
library(hetGP)
library(mgcv)
library(plotly)


addErrorLimits <- function(data, average, error)
{
  
  data <- data %>% mutate("{average}_lwr":=.data[[average]]-.data[[error]],"{average}_upr":=.data[[average]]+.data[[error]])
  
  return (data)
}


effectiveError <- function( data)
{
  return (   sqrt(var(data)/effectiveSize(data)))
  #return (   sqrt(var(data)/length(data)))
}

generateX <- function( x,x_new=NULL)
{
  x_pred=x_new
  if (is.null(x_new) )
  {
    N=100
    maxx=max(x)
    minx=min(x)
    deltax=(maxx-minx)/as.double(N)
    x_pred=seq( minx,maxx,deltax )
  }
  return (x_pred )
}

gpFit <- function(data,x,y,x_new=NULL )
{
  x_pred=generateX(data[[x]],x_new)
  fit= mleHomGP(data[[x]],data[[y]])
  pred_res=predict(fit,as.matrix(x_pred))
  print (pred_res$sd)
  res= tibble( "{x}" := x_pred ,  "{y}":=pred_res$mean , "{y}_lwr":=pred_res$mean - pred_res$sd , "{y}_upr":=pred_res$mean + pred_res$sd)
  return (res)  
}

bootstrapAverage <- function( data ,  f ,nBootstraps=10 )
{
  M_b <- data  %>% bootstraps(times=nBootstraps )
  mu <- M_b[["splits"]] %>% map_dfr( ~ f( analysis(.x)  ) )
  bs <- mu %>% summarise( across( .fns = c(mean=mean,error = ~ sqrt(var(.x)) ), .names = "{.col}_{.fn}"  )      )
  
  
  return (bs)
}

stripMeanNames <- function(.data)
{
  return(.data %>% rename_with( ~ str_replace(.x,"_mean",""  ) ) )
}


