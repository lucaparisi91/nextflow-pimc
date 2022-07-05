#!/usr/bin/env python
import pandas as pd
import os
from pathlib import Path
import numpy as np
import tqdm
import argparse
import re

def expand_key(data,key="key"):
    rows=[]
    for name in data[key]:    
        print(name)
        res={}
        for label in name.split("_"):
            m=re.match("([a-zA-Z]+)(.*)",label)
            res[m[1]]=[m[2]]
        res=pd.DataFrame(res)
        rows.append(res)
    parameters=pd.concat(rows).reset_index(drop=True)
    return pd.merge(data.drop(key,axis=1).reset_index(drop=True),parameters,left_index=True,right_index=True)


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Expand the dataframe")
    parser.add_argument("data",type=str,help="Filename of a dataframe")
    parser.add_argument("--out",type=str,help="Output file",default="expanded.dat")

    args = parser.parse_args()


    data=pd.read_csv( args.data , delim_whitespace=True)
    data=expand_key(data)
    data.to_csv(args.out,sep="\t")