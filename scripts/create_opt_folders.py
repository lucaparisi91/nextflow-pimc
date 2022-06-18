#!/usr/bin/env python
import scipy
from pimc import singleComponentCanonical,inputFileTools
import pandas as pd
import numpy as np
import os
from pathlib import Path
import tqdm
import argparse

parser = argparse.ArgumentParser(description="Schedule optimizations")
parser.add_argument("input_file",type=str)
parser.add_argument('--minC', type=float,
                    help='log of minC',default=-10)
parser.add_argument('--maxC', type=float,
                    help='log of maxC',default=-4)
parser.add_argument('--n', type=int,
                    help='Number of optimizations to schedule',default=10)
parser.add_argument('--ensamble', type=str,
                    help='Ensamble',default="canonical")

args = parser.parse_args()

minC=args.minC
maxC=args.maxC
nOpt=args.n
input_file=args.input_file
output_folder="."
ensamble=args.ensamble


data=pd.read_csv( input_file ,delim_whitespace=True).reset_index(drop=True)

print("Creating optimization files...")
for i,row in tqdm.tqdm(data.iterrows(),total=len(data)):
    data_opt = pd.DataFrame(  [row.values] , columns=row.index )
    CAS=np.logspace( minC, maxC,nOpt)
    for CA in CAS:
        data_opt["CA"]=CA
        if ensamble == "semiCanonical":
            data_opt["CB"]=data_opt["CA"]

            if "pMin" in data_opt.columns:
                p0=0.5*(data_opt["pMin"] + data_opt["pMax"])
                data_opt["CB"]=data_opt["CA"]*(1+p0)/(1-p0)

            data_opt["CAB"]=data_opt["CA"]*data_opt["CB"]

        
        #js=singleComponentCanonical.generateInputFiles(data_opt)
        opt_label="CA{:2.3e}".format(CA)
        opt_file="parameters_{}.dat".format(opt_label)
        data_opt.to_csv(opt_file,sep=" ")


    #run_folder=os.path.join(folder_run,labels[i])    
    #Path(run_folder).mkdir(parents=True, exist_ok=True)
