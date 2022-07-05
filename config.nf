executor {
    name = 'slurm'
    queueSize = 300
}

executor {
    name = 'local'
    cpus= 1
}

process.executor = 'local'
