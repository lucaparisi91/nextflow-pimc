#!/usr/bin/env python
import pandas as pd
import os
from pathlib import Path
import numpy as np
import tqdm
import argparse

parser = argparse.ArgumentParser(description="Create an external input folder")
parser.add_argument("data_left",type=str,help="Filename of a dataframe")
parser.add_argument("data_right",type=str,help="Filename of a dataframe")
parser.add_argument("--out",type=str,help="Output file",default="merged.dat")


args = parser.parse_args()


data_left=pd.read_csv( args.data_left , delim_whitespace=True)
data_right=pd.read_csv( args.data_right , delim_whitespace=True)
data=pd.merge( data_left,data_right , how="cross")

data.to_csv(args.out,sep="\t")
