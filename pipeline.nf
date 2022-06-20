#!/usr/bin/env nextflow

params.runs = "$projectDir/sims.dat"
nextflow.enable.dsl=2


process create_optimizations {

    input:
    tuple val(key) , path(data)

    output:
    tuple val(key) , path("opt_${data}")

    """
    $baseDir/scripts/create_opt_folders.py $data --out "opt_${data}"
    """
}


process split_runs {

    input:
    tuple val(key) , path(data)

    output:
    tuple val(key), path("split/*.dat")

    """
    $baseDir/scripts/split_rows.py $data --out "split"
    """
}

process generate_input_files
{
    input:
        tuple val(key), path("parameters.dat")
    output:
        tuple val(key) , path("input.json")
    """
    $baseDir/scripts/create_folder.py parameters.dat
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
        tuple val(key),path ("input.json")
    output:
        tuple val(key), path ("ratio.dat")
    """
    module load Boost
    module load HDF5
    ~/qmc/build-3D/pimc/pimc input.json >  pimc.out
    """
}


process run_main_run
{
    executor 'slurm'
    cpus 1
    time '48h'
    queue 'defq'
    errorStrategy 'retry'
    clusterOptions '-J run'

    input: 
        tuple val(key), path("input.json")
    output:
        tuple val(key), path("run/*")

    """
    module load Boost
    module load HDF5
    mkdir run
    cd run
    ~/qmc/build-3D/pimc/pimc ../input.json >  ../pimc.out
    """
}

process anal_observable
{
    input:
        tuple val(key),path(parameters),path(observable)
    output:
        tuple val(key),path( "observable_merged.dat")
    """
    $baseDir/scripts/cross.py $observable $parameters --out observable_merged.dat
    """
}

process gather_observable
{
    publishDir "$projectDir/agg/$key"

    input:
        tuple val(key), path( "observable*.dat")
    output:
        tuple val(key), path( "collect_data.dat")
    
    """
    $baseDir/scripts/gather.py observable*.dat --out collect_data.dat
    """
}


process optimized_parameter
{
    input:
        tuple val(key), path(parameters_file),path(ratios_file)
    output:
        tuple val(key), path ("opt_${parameters_file}")
    """
        $baseDir/scripts/optimization.R $ratios_file --out Z.dat
        $baseDir/scripts/plan_optimized.py $parameters_file Z.dat --out opt_${parameters_file}
    """
}

process process_for_main_run
{
    input:
        tuple val(key), path ("parameters.dat")
    output:
        tuple val(key), path ("parameters_main_run.dat")
    script:
    """
    #!/usr/bin/env python
    import pandas as pd
    data=pd.read_csv("parameters.dat",delim_whitespace=True)
    data["nBlocks"]=1000
    data.to_csv("parameters_main_run.dat",sep="\t")
    """
}


/*
 * Define the workflow
 */

workflow optimize {
    take: sims
    main:
        grouped_sims = sims | map{ file -> tuple( file[1].name.toString().tokenize('_').get(0),file[1] )} 
        params_files = grouped_sims | create_optimizations | split_runs | transpose | map { el -> tuple( tuple(el[0],el[1].getName()) , el[1]   )   } 
        input_files = generate_input_files(params_files)
        opt_ratios = run_opt_run(input_files)
        obs = params_files.join(opt_ratios) | anal_observable

        ratios = obs | map { el -> tuple( el[0][0],el[1]  )} | groupTuple | gather_observable
        opt_sims = grouped_sims.join(ratios) | optimized_parameter
    emit:
        opt_sims
}

workflow run_main
{
    take:
        sims
    main:
        res = sims  | process_for_main_run | generate_input_files | run_main_run
    emit:
        res
}

def filter_observable(files)
{
    return files.find { it ==~/.*rho\.dat$/ }
}

workflow
{
    opt_sims=split_runs( tuple("T0.6",params.runs) ) | transpose  |  optimize
    out_main=run_main(opt_sims)
    main_obs=out_main.map{ el -> tuple( el[0],filter_observable(el[1]) )  }
    main_ob=opt_sims.join(main_obs) | anal_observable | map { el -> tuple("main",el[1]) }   | groupTuple() | gather_observable

}