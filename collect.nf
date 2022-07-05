#!/usr/bin/env nextflow

nextflow.enable.dsl=2
params.label="M"
params.nBlocks=100
params.x_column="M"

process anal_observable
{
    tag "$key"


    input:
        tuple val(key),path("observable.dat")
    output:
        tuple val(key),path( "blocked_observable.dat")
    """
    #!/usr/bin/env python
    from scripts import average_blocks
    import pandas as pd
    data=pd.read_csv( "observable.dat" , delim_whitespace=True).dropna()
    data=average_blocks.average_blocks(data,nBlocks=${params.nBlocks},parameters="${params.x_column}",burnin=0)
    data["key"]="$key"
    data.to_csv("blocked_observable.dat",sep="\t")
    """
}

process gather_observable
{
    tag "$key"
    input:
        tuple val(key), path( "observable*.dat")
    output:
        tuple val(key), path( "collect_data.dat")
    
    """
    $baseDir/scripts/gather.py observable*.dat --out collect_data.dat   
    """
}

process expand_key
{
    tag "$key"

    input:
        tuple val(key),path("data.dat")
    output:
        tuple val(key),path("data_expanded.dat")
    """
    $baseDir/scripts/expand_key.py data.dat --out data_expanded.dat
    """
}


process publish_file
{
    publishDir "$projectDir/agg"
    input:
        tuple val(key),path("file.dat")
    output:
        path("$key")
    """
    cp file.dat $key
    """
}

workflow
{
    files=Channel.fromPath( params.input ) | filter { it -> it==~ /.*${params.label}\.dat/ }| map { it -> tuple(it.toString().split("/")[-3] , it)}
    files  | anal_observable | map {it -> tuple( "${params.label}.dat",it[1] ) } | groupTuple | gather_observable | expand_key | publish_file

}
