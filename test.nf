#!/usr/bin/env nextflow
nextflow.enable.dsl=2

process test_process_1 {
    input:
    val(key)
    output:
    path "out"
    """
    echo "$key" > out
    """
}



process test_process_2 {
    input:
    val(key)
    output:
    path "out"
    """
    echo "$key" > out
    """
}

process combine_process {
    input:
    path("in1")
    path("in2")
    output:
    stdout
    """
    key1=\$(cat in1)
    key2=\$(cat in2)
    echo \${key1}-\${key2}
    """
}

workflow
{
    res1=Channel.of("1","2","3","4") | test_process_1
    res2=Channel.of("1","2","3","4") | test_process_2
    combine_process(res1,res2) | view
}