#!/bin/bash

#SBATCH --nodes=1
#SBATCH --time=24:00:00
#SBATCH --ntasks=1 # number of processes
#SBATCH --cpus-per-task=1
#SBATCH --mem=480G
#SBATCH --account=Sis25_piasini       # account name
#SBATCH --partition=boost_usr_prod # partition name
#SBATCH --job-name=ViTPose_feats
#SBATCH --output=/leonardo/home/userexternal/tcausin0/output_jobs/%x.%j.out   # file name will be *job_name*.*job_id*
cd /leonardo/home/userexternal/tcausin0/Project1917/code/py_scripts
module load python/3.10.8--gcc--8.5.0
module load hdf5/1.14.3--gcc--12.2.0
source $HOME/virtual_envs/1917_py_env/bin/activate

cd /leonardo/home/userexternal/tcausin0/SIP_package
python /leonardo/home/userexternal/tcausin0/Project1917/code/py_scripts/extract_ViTPose_feats.py
