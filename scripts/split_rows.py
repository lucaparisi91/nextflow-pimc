#!/usr/bin/env python
import scipy
from pimc import singleComponentCanonical,inputFileTools
import pandas as pd
import numpy as np
import os
from pathlib import Path
import tqdm
import argparse
import copy

parser = argparse.ArgumentParser(description="Schedule optimizations")
parser.add_argument("input_file",type=str)
parser.add_argument('--out', type=str,
                    help='Folder where to save splitted files',default=".")


args = parser.parse_args()
data=pd.read_csv( args.input_file ,delim_whitespace=True).reset_index(drop=True)
for i,row in tqdm.tqdm(data.iterrows(),total=len(data)):
    data_row = pd.DataFrame(  [row.values] , columns=row.index )    
    label="{:d}".format(i)
    if "label" in data_row.keys():
        label=str(data_row["label"][0])
    print(label)
    label="{}.dat".format(label)
    Path(args.out).mkdir(parents=True, exist_ok=True)
    data_row.to_csv(os.path.join(args.out,label),sep="\t")