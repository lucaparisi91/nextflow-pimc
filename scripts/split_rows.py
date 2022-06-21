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
parser.add_argument('--label', type=str,
                    help='Column to use as a label for files. Should be unique',default=None)


args = parser.parse_args()
data=pd.read_csv( args.input_file ,delim_whitespace=True).reset_index(drop=True)
for i,row in tqdm.tqdm(data.iterrows(),total=len(data)):
    data_row = pd.DataFrame(  [row.values] , columns=row.index )    
    
    if args.label is not None:
        label="{}{}".format(args.label ,str(data_row[args.label][0]) )
    else:
        label="{:d}".format(i)
    
    Path(args.out).mkdir(parents=True, exist_ok=True)
    data_row.to_csv(os.path.join(args.out,label),sep="\t")