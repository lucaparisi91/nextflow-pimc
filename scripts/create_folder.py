#!/usr/bin/env python
import scipy
from pimc import singleComponentCanonical,inputFileTools,twoComponentSemiCanonical,twoComponentCanonical
import pandas as pd
import numpy as np
import os
import argparse

parser = argparse.ArgumentParser(description="Create an external input folder")
parser.add_argument("input_file",type=str,help="dataframe file in csv format and blank delimiters")
parser.add_argument('--output_dir', type=str, help="json file input of the PIMC simulation",default=".")
parser.add_argument('--ensamble', type=str, help='Ensamble',default="canonical")
parser.add_argument('--nComponents', type=int, help='Number of components',default=None)


args = parser.parse_args()
input_file=args.input_file
folder=args.output_dir
ensamble=args.ensamble

data=pd.read_csv( input_file,delim_whitespace=True).reset_index(drop=True)


if (data.shape[0] != 1) :
    raise RuntimeError("Should only be one row in the dataframe")

creatorModule=singleComponentCanonical
if ensamble=="semiCanonical":
    creatorModule=twoComponentSemiCanonical
    assert( (args.nComponents == 2 )or (args.nComponents is None)  )
    
else:
     if ensamble=="canonical":
        if args.nComponents==1 or args.nComponents==None:
            creatorModule=singleComponentCanonical
        else:
            if args.nComponents==2:
                creatorModule=twoComponentCanonical


j=creatorModule.generateInputFiles(data)[0]


settings=[ {"folder" : folder , "jSon" : [ [ "input.json"  , j  ] ] } ]    

inputFileTools.createSimFolders(settings)