codeDir="/mnt/nfs/home/nlp102/data/pimc-python/nextflow"


process create_optimizations {

    input:
    tuple val(key) , path(data)

    output:
    tuple val(key) , path("opt_${data}")

    """
    $codeDir/scripts/create_opt_folders.py  $data --ensamble ${params.ensamble} --nComponents ${params.nComponents} --out "opt_${data}"
    """
}

process split_runs{

    input:
    tuple val(key) , path(data)
    val label
    output:
    tuple val(key), path("split/*")
    """
    $codeDir/scripts/split_rows.py $data --out split --label $label
    """
}

process generate_input_files
{
    input:
        tuple val(key), path("parameters.dat")
    output:
        tuple val(key) , path("input.json")
    """
    $codeDir/scripts/create_folder.py --ensamble ${params.ensamble} --nComponents ${params.nComponents} parameters.dat
    """
}

process run_opt_run
{
    publishDir "$projectDir/opt/${key[0]}_${key[1]}"

    errorStrategy "ignore"
    tag "${key[0]}_${key[1]}"
    executor 'slurm'
    cpus 1
    time "${params.optTime}h"
    queue 'defq'
    queueSize=350
    clusterOptions "-J opt(${params.name})-${key[0]}_${key[1]}"

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
    publishDir "$projectDir/run/${key[0]}_${key[1]}"

    tag "${key[0]}_${key[1]}"
    executor 'slurm'
    cpus 1
    time "${params.runTime}h"
    queue 'defq'
    queueSize=350
    errorStrategy 'ignore'
    clusterOptions "-J run(${params.name})-${key[0]}_${key[1]}"


    input: 
        tuple val(key), path("input.json")
    output:
        tuple val(key), path("run/*")

    """
    echo $key
    module load Boost
    module load HDF5
    mkdir run
    cp input.json run
    cd run
    ~/qmc/build-3D/pimc/pimc input.json >  pimc.out
    """
}

process restart_main_run
{
    publishDir "$projectDir/${key[0]}_${key[1]}"
    tag "${key[0]}_${key[1]}"
    executor 'slurm'
    cpus 1
    time '1h'
    queue 'defq'
    queueSize=350
    errorStrategy 'ignore'
    clusterOptions "-J run(${key[0]}_${key[1]})"

    input: 
        tuple val(key),path("input.json"),path("latest.hdf5")
    output:
        tuple val(key), path("run/*")
    
    """
    echo $key
    module load Boost
    module load HDF5
    mkdir run
    cp input.json run
    cp latest.hdf5 run
    cd run
    ~/qmc/build-3D/pimc/pimc ../input.json >  ../pimc.out
    """
}



process anal_observable
{
    input:
        tuple val(key),path(parameters),path(observable)
        val(average_parameters)
    output:
        tuple val(key),path( "observable_merged.dat")
    """
    $codeDir/scripts/average_blocks.py $observable --parameters=$average_parameters --out blocked_$observable --nBlocks 100
    $codeDir/scripts/cross.py blocked_$observable $parameters --out observable_merged.dat
    """
}

process anal_ratio
{
    input:
        tuple val(key),path(parameters),path(observable)
    output:
        tuple val(key),path( "observable_merged.dat")
    """
    $codeDir/scripts/average_blocks.py $observable --nBlocks 100 --out blocked_$observable --burnin 10
    $codeDir/scripts/cross.py blocked_$observable $parameters --out observable_merged.dat
    """
}

process gather_observable
{
    input:
        tuple val(key), path( "observable*.dat")
    output:
        tuple val(key), path( "collect_data.dat")
    
    """
    $codeDir/scripts/gather.py observable*.dat --out collect_data.dat
    """
}


process optimized_parameter
{
    input:
        tuple val(key), path(parameters_file),path(ratios_file)
    output:
        tuple val(key), path ("opt_${parameters_file}")
    """
        $codeDir/scripts/optimization.R $ratios_file --out Z.dat --nComponents ${params.nComponents}
        $codeDir/scripts/plan_optimized.py $parameters_file Z.dat --out opt_${parameters_file} --ensamble ${params.ensamble} --nComponents ${params.nComponents}
    """
}

process process_for_main_run
{
    errorStrategy "ignore"
    input:
        tuple val(key), path ("parameters.dat")
    output:
        tuple val(key), path ("parameters_main_run.dat")
    script:
    """
    #!/usr/bin/env python
    import pandas as pd
    import numpy as np

    data=pd.read_csv("parameters.dat",delim_whitespace=True)
    data["nBlocks"]=${params.runNblocks}
    data["maxTime"]=int(float(${params.runTime} ) * 0.9 * 60 * 60 ) 
    data["stepsPerBlock"]=1000
    seed=pd.DataFrame({"seed" : np.arange(567,567+10)})
    data=pd.merge( data.drop("seed",axis=1),seed,how="cross")
    data.to_csv("parameters_main_run.dat",sep="\t")
    """
}



workflow optimize {
    take: sims
    main:
        grouped_sims = sims | map{ file -> tuple( file[1].getName(),file[1] )} 
        tab=grouped_sims | create_optimizations
        params_files = split_runs(tab,"CA") | transpose | map { el -> tuple( tuple(el[0],el[1].getName()) , el[1]   )   } 
        input_files = generate_input_files(params_files)
        opt_ratios = run_opt_run(input_files)
        obs = params_files.join(opt_ratios) | anal_ratio

        ratios = obs | map { el -> tuple( el[0][0],el[1]  )} | groupTuple(size:10) | gather_observable
        opt_sims = grouped_sims.join(ratios) | optimized_parameter
    emit:
        opt_sims
}

process publish_file
{
    publishDir "$projectDir/agg", mode: 'symlink'
    input:
    path input_file
    val name
    output:
    path name
    """
    cp $input_file $name
    """
}


def filter_observable(files,name)
{
    return files.find { it.toString() ==~/.*\/${name}.dat/ }
}

/* workflow run_main
{
    take:
        sims
    main:
        sims2 = sims | process_for_main_run 
        parameters = split_runs(sims2,"seed") | transpose | map { el -> tuple( tuple(el[0],el[1].getName()) , el[1]   )   }
        input_files = generate_input_files(parameters)
        res = run_main_run(input_files)
        obs=res | map { it -> tuple(it[0],filter_observable(it[1]) ) }
        obs=parameters.join(obs) | anal_observable
        obs_collected = obs | map {el -> tuple("None",el[1] )    } | groupTuple(size:10) | gather_observable | map {el -> el[1]}
        publish_file(obs_collected,"M.dat" )

    emit:
        res
        parameters
}
 */


workflow generate_seed
{
    take:
        parameters
    main:
        parameters_seeded = parameters | process_for_main_run
        parameters2 = split_runs(parameters_seeded,"seed") | transpose | map { el -> tuple( tuple(el[0],el[1].getName()) , el[1]   )   }
    emit:
        parameters2
}

workflow run_main
{
    take:
        parameters
    main:
        input_files = generate_input_files(parameters)
        res = run_main_run(input_files)
    emit:
        res
        parameters
}

workflow collect_observable
{
    take:
        res
        parameters
        name
        x
    main:
        obs=res | map { it -> tuple(it[0],filter_observable(it[1],name) ) }
        obs= anal_observable(parameters.join(obs) , x )
        obs_collected = obs | map {el -> tuple("None",el[1] )    } | groupTuple | gather_observable | map {el -> el[1]}
    emit:
        obs_collected
}


def selectInputs( el )
{
    return tuple( el[0],el[1].find {  it.toString() ==~ /.*\/input.json/  }, el[1].find {  it.toString() ==~ /.*\/latest.hdf5/  }   )
}




workflow restart
{
    take:
        res
        parameters
    main:
        inputFiles = res | map { el -> selectInputs(el) }
        res2 = restart_main_run(inputFiles)
    emit:
        res
        parameters
}
