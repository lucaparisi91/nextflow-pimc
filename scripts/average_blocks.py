import pandas as pd
import os
from pathlib import Path
import numpy as np
import tqdm
import argparse


parser = argparse.ArgumentParser(description="Create an external input folder")
parser.add_argument("data",type=str,help="Filename of a dataframe")
parser.add_argument("--nBlocks",help="Number of blocks to average over",default=100,type=int)
parser.add_argument("--parameters",type=str,help="Output file",nargs="+", default=None)
parser.add_argument("--out",type=str,help="Output file",default="averaged.dat")

args = parser.parse_args()

def average_blocks(data,nBlocks=100):

    blocks=np.array_split(data,nBlocks)
    datas=[  block.agg(["mean"]).reset_index(drop=True)   for block in blocks    ]
    
    out=pd.concat(datas)
    return(out)


data=pd.read_csv( args.data , delim_whitespace=True)

if args.parameters is None:
    data=average_blocks(data,nBlocks=args.nBlocks)
else:
    data=data.groupby(args.parameters).apply(lambda x : average_blocks(x,nBlocks=nBlocks) ).reset_index(drop=True)


data.to_csv(args.out,sep="\t")