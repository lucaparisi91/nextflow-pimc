#!/usr/bin/env Rscript
source("/mnt/storage/nobackup/nlp102/pimc-python/nextflow/scripts/model.R")
library(argparser, quietly=TRUE)

# Create a parser
p <- arg_parser("Extimate The ratio between open and closed sector partition functions")

# Add command line arguments
p <- add_argument(p, "ratios", help="Dataframe contining the output ratios")
p <- add_argument(p, "--ensamble", help="canonical/semiCanonical ensamble", default="canonical")
p <- add_argument(p, "--out", help="file name where to save a dataframe containing the partition functions", default="Z.dat")
argv <- parse_args(p)



create_single_component <- function(ratio_filename,Z_filename)
{

  data=read_delim( ratio_filename,delim = "\t") %>% drop_na()


  parameter="CA"
  groups=c("N")
  ob = "cRatio"
  nBlocks=10

  averageBlock <- function(data,n=10)
  {
    data %>% split(  seq_along(rownames(data))%%nBlocks     ) %>% map_dfr(~ summarize(.x,across(.fns=mean)))  %>% mutate(iteration=seq_along(iteration) )
  }
  data <- data %>% group_by( across(all_of(parameter))) %>% group_modify( ~ averageBlock(.x) ) 

  plot <- ggplot( data=data,aes(x=.data[["iteration"]],y=.data[[ob]],color=as.factor(.data[[parameter]]) )) + geom_point( aes_string(y=ob)  )

  ggsave("ccRatio.pdf",plot)

  ############### FILTERING ############################
  averageRatios <- data %>% group_by( across(all_of(c(groups,parameter)))) %>% summarise( across(.cols=c("cRatio","oRatio"),.fns=mean) )
  averageRatios
  filteredRatios <- averageRatios %>% filter(cRatio<0.99  & oRatio > 0.01)
  filteredRatios
  data <- inner_join( data, filteredRatios %>% select( .data[["CA"]])  )
  data
  ################## EXTRACT Z #########################################

  #noc <- function(data) { return (tibble( ZA =  log(mean(data[["ocRatio"]])/mean(data[["ccRatio"]])), ZAB =  log(mean(data[["ooRatio"]])/mean(data[["ccRatio"]]))  , ZB =  log(mean(data[["coRatio"]])/mean(data[["ccRatio"]]))
  #)   )  }

  noc <- function(data) {  return (tibble( ZA =  log(mean(data[["oRatio"]])/mean(data[["cRatio"]])    )      ) )   }


  NOC_data <- data %>% group_by(across(all_of(  c("CA") ))) %>% group_modify( ~ bootstrapAverage(.x, noc) )  %>%drop_na() %>% mutate(ZA_mean=ZA_mean-log(CA),ZA_error=ZA_error ) 
  #%>%   mutate(ZAB_mean=(ZAB_mean-log(CAB))/N,ZAB_error=ZAB_error/N ) %>% mutate(ZB_mean=(ZB_mean-log(CB))/N,ZB_error=ZB_error/N )
  NOC_data

  NOC_data <- NOC_data %>% addErrorLimits(average="ZA_mean",error="ZA_error") 
  #%>% addErrorLimits("ZAB_mean","ZAB_error") %>%addErrorLimits(average="ZB_mean",error="ZB_error")
  Z <- NOC_data %>% stripMeanNames()
  #write_delim(Z,snakemake@output[[2]],delim="\t")

  plot <- ggplot( data=Z,aes(x=CA,y=.data[["ZA"]] ) )+ geom_point( aes_string(y="ZA")  ) + geom_errorbar(aes(ymin=ZA_lwr,ymax=ZA_upr)) + geom_smooth(method="lm" )
  #ggsave("Z.pdf",plot)
  Z <- Z %>% ungroup() %>%summarise( ZA_error=sqrt(var(ZA)/length(ZA)),ZA=mean(ZA) )

  write_delim(Z,Z_filename,delim="\t")
}

create_two_component <- function(ratio_filename,Z_filename)
{
  # import 
  data=read_delim(ratio_filename,delim = "\t") %>% drop_na()
  data$folder <- NULL
  data
  groups <- c()
  #M <-  M %>% filter( abs(.data$inverseTemperature - 1.42857142857143)<1e-2)
  parameter="CA"
  ob = "ccRatio"
  blockAverage<- function( data,  n=10 )
  {

  data %>% split(  seq_along(rownames(data))%%n     ) %>% map_dfr ( ~ .x%>% summarise( across(.fns = mean  ) ) ) %>% mutate(iteration=seq_along(iteration) )
  }

  data <- data %>% group_by( across(all_of(c(groups,"CA")))) %>% group_modify(  ~  blockAverage(.x) ) 

  #plot <- ggplot( data=data,aes(x=.data[["iteration"]],y=.data[[ob]],color=as.factor(.data[[parameter]]) )) + geom_point( aes_string(y=ob)  ) + facet_grid( nBeads  ~N) 

  #ggplotly(plot)

  ############### FILTERING ############################

  averageRatios <- data %>% group_by( across(all_of(c(groups,parameter)))) %>% summarise( across(.cols=c("ccRatio","ocRatio","coRatio","ooRatio"),.fns=mean) )
  filteredRatios <- averageRatios %>% filter(ccRatio<0.9  & ooRatio > 0.1)
  data <- inner_join( data, filteredRatios %>% select( .data[["CA"]])  )
  ################## EXTRACT Z #########################################

  noc <- function(data) { return (tibble( ZA =  log(mean(data[["ocRatio"]])/mean(data[["ccRatio"]])), ZAB =  log(mean(data[["ooRatio"]])/mean(data[["ccRatio"]]))  , ZB =  log(mean(data[["coRatio"]])/mean(data[["ccRatio"]]))
                                        )   )  }

  sectors=c("A","B","AB")

  sectorCoefficients <- map_chr( sectors, ~ str_glue("C{.x}"))

  NOC_data <- data %>% group_by(across(all_of(  c(groups,sectorCoefficients ) ))) %>% group_modify( ~ bootstrapAverage(.x, noc) )  %>%drop_na() %>% mutate(ZA_mean=(ZA_mean-log(CA)),ZA_error=ZA_error ) %>%   mutate(ZAB_mean=(ZAB_mean-log(CAB)),ZAB_error=ZAB_error ) %>% mutate(ZB_mean=(ZB_mean-log(CB)),ZB_error=ZB_error )


  NOC_data <- NOC_data %>% addErrorLimits(average="ZA_mean",error="ZA_error")  %>% addErrorLimits("ZAB_mean","ZAB_error") %>%addErrorLimits(average="ZB_mean",error="ZB_error")

  Z <- NOC_data %>% stripMeanNames()
  Z

  sectors <-c("ZA","ZB","ZAB") 
  for ( sector in sectors ) {
    plot <- ggplot( data=Z,aes(x=CA,y=.data[[sector]] ) )+ geom_point( aes_string(y=sector)  ) + geom_errorbar(aes_string(ymin=str_glue("{sector}_lwr"),ymax=str_glue("{sector}_upr") ),width=5e-2*max(Z$CA))  + geom_smooth(method="lm" )
    #ggsave(str_glue("{sector}.pdf"),plot=plot )
  }


  #write_delim(Z,snakemake@output[[2]],delim="\t")


  Z_summ <- Z %>% ungroup() %>%summarise( ZA_error=sqrt(var(ZA)/length(ZA)),ZA=mean(ZA),ZB_error=sqrt(var(ZB)/length(ZB)),ZB=mean(ZB),ZAB_error=sqrt(var(ZAB)/length(ZAB)),ZAB=mean(ZAB) )

  write_delim(Z_summ,Z_filename,delim="\t")
}

if (argv$ensamble == "semiCanonical") {
  create_two_component(argv$ratios,argv$out)
} else {
  create_single_component(argv$ratios,argv$out)
}
