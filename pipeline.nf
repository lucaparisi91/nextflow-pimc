#!/usr/bin/env nextflow
nextflow.enable.dsl=2

params.runs = "$projectDir/sims.dat"


process create_optimizations {

    input:
    path "sims.dat"
    
    output:
    path 'parameters*.dat'

    """
    $baseDir/scripts/create_opt_folders.py sims.dat
    """
}

process generate_input_files
{
    input:
        path parameter_file
    output:
        path "input.json"
    """
    $baseDir/scripts/create_folder.py $parameter_file
    """
}

process run_opt_run
{
    executor 'slurm'
    cpus 1
    time '10h'
    queue 'defq'
    errorStrategy 'retry'
    clusterOptions '-J opt'

    input: 
        path "input.json"
    output:
        path "ratio.dat"
    """
    module load Boost
    module load HDF5
    ~/qmc/build-3D/pimc/pimc input.json >  pimc.out
    """
}

process anal_observable
{
    input:
        path data
        path parameters
    output:
        path "${parameters}_merged.dat"
    """
    $baseDir/scripts/cross.py $data $parameters --out ${parameters}_merged.dat
    """
}


process gather_observable
{
    input:
        path files
    output:
        path "collect_data.dat"
    """
    $baseDir/scripts/gather.py $files --out collect_data.dat
    """
}

process optimized_parameter
{
    publishDir "$projectDir"

    input:
        path parameters_file
        path ratios_file
    output:
        path "opt_${parameters_file}"
    """
        $baseDir/scripts/optimization.R $ratios_file --out Z.dat
        $baseDir/scripts/plan_optimized.py $parameters_file Z.dat --out opt_${parameters_file}
    """
}

/*
 * Define the workflow
 */

workflow {
    
    params_files = create_optimizations(params.runs) | flatten 
    input_files = generate_input_files(params_files)
    opt_ratios = run_opt_run(input_files)
    obs = anal_observable(opt_ratios,params_files)
    ratios = obs | collect | gather_observable
    optimized_parameter(params.runs,ratios)



}
