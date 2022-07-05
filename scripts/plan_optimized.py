#!/usr/bin/env python
import pandas as pd
import numpy as np
import argparse

parser = argparse.ArgumentParser(description="Create an external input folder")
parser.add_argument("parameters",type=str,help="File with simulation parameters")
parser.add_argument('Z', type=str, help="File with open/closed partition functions estimates",default=".")
parser.add_argument('--nComponents', type=int, help='Number of components in the simulation',default=1)
parser.add_argument('--out', type=str, help='output file',default="parameters.dat")
parser.add_argument('--ensamble', type=str, help='Ensamble',default="canonical")

args = parser.parse_args()


r_close = 0.6 
r_ab_a = 100
r_b_a = 1

Z=pd.read_csv( args.Z , delim_whitespace=True)
sims=pd.read_csv( args.parameters , delim_whitespace=True)

if args.ensamble == "semiCanonical":
    CA=(1/r_close - 1)/( np.exp(Z["ZA"])*( 1 + r_b_a + r_ab_a ) )
    CB=r_b_a*CA*np.exp(Z["ZA"] - Z["ZB"])
    CAB=r_ab_a*CA*np.exp(Z["ZA"] - Z["ZAB"])
    
    sims["CA"]=CA
    sims["CB"]=CB
    sims["CAB"]=CAB

else:
    if args.nComponents==1:
        CA=(1/r_close - 1)/np.exp(Z["ZA"])
        sims["CA"]=CA
    else:
        if args.nComponents==2:
            A=np.exp(Z["ZA"] + Z["ZAB"] - Z["ZB"])*r_b_a
            B=np.exp(Z["ZA"] )*(1 + r_b_a)
            C=1-1/r_close
            CA=(-B + np.sqrt( B**2 - 4*A*C  ) )/(2*A)
            CB=r_b_a*CA*np.exp(Z["ZA"] - Z["ZB"]   )
            sims["CA"]=CA
            sims["CB"]=CB
            

sims=sims.loc[:,sims.columns != "folders"].drop_duplicates().dropna()

sims.to_csv(args.out,sep="\t")
