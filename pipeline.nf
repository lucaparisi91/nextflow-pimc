#!/usr/bin/env nextflow

params.runs = "$projectDir/sims.dat"
params.name = "freeEnergyr1"
params.optTime = 6
params.runTime = 48
params.runNblocks = 10000

params.ensamble = "semiCanonical"
params.nComponents = 2
nextflow.enable.dsl=2


include {split_runs; optimize; generate_seed; run_main; collect_observable; publish_file } from "./module.nf"

workflow
{
    opt_sims=split_runs( tuple( params.name,params.runs) , "N pMin ratio") | transpose | optimize
    main_sims=opt_sims | generate_seed | run_main
}
