#!/usr/bin/env python
import pandas as pd
import os
from pathlib import Path
import numpy as np
import tqdm
import argparse


def _average_blocks(data,nBlocks=100):    
    blocks=np.array_split(data,nBlocks)

    datas=[  block.agg(["mean"]).reset_index(drop=True)   for block in blocks    ]
    
    out=pd.concat(datas)
    return(out)

def average_blocks(data,nBlocks=100,parameters=None,burnin=0):
    data=data.iloc[burnin:]
    if parameters is None or parameters==[""] or parameters=="":
        data=_average_blocks(data,nBlocks=nBlocks)
    else:
        data=data.groupby(parameters).apply(lambda x : _average_blocks(x,nBlocks=nBlocks) ).reset_index(drop=True)
    return data



if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Create an external input folder")
    parser.add_argument("data",type=str,help="Filename of a dataframe")
    parser.add_argument("--nBlocks",help="Number of blocks to average over",default=100,type=int)
    parser.add_argument("--parameters",type=str,help="Output file",nargs="+", default=None)
    parser.add_argument("--out",type=str,help="Output file",default="averaged.dat")
    parser.add_argument("--burnin",type=int,help="Number of initial steps to be truncated",default=0)

    args = parser.parse_args()

    data=pd.read_csv( args.data , delim_whitespace=True).dropna()
    data=average_blocks(data,nBlocks=args.nBlocks,parameters=args.parameters,burnin=args.burnin)
    data.to_csv(args.out,sep="\t")
