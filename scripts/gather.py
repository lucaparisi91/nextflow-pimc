#!/usr/bin/env python
import pandas as pd
import os
from pathlib import Path
import numpy as np
import tqdm
import argparse

parser = argparse.ArgumentParser(description="Create an external input folder")
parser.add_argument("input_files",type=str,help="Input files to concatenate",nargs="+")
parser.add_argument("--out",type=str,help="Output filed",default="gathered.dat")

args = parser.parse_args()
input_files=args.input_files
out_file=args.out

def gather(inputFiles):
    '''
    Collect data from inputFiles and merge with dataframe runs containing parameters and a folder colum. Gatherered data is merged with the row containing the parent directory of the inputfile
    '''
    datas=[]
    for filename in tqdm.tqdm(inputFiles):
        data=pd.read_csv( filename , delim_whitespace=True)
        datas.append(data)

    data=pd.concat(datas)
    return (data)


data=gather(input_files)
data.to_csv(out_file,sep="\t")