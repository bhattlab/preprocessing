## First time setup

First, install [miniconda3](https://conda.io/miniconda.html) on the cluster, as that's where you should be doing most of your workflow work.

```
# ON SCG
# to download installer
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
# to run installer
bash https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
# follow instructions, select a place to install miniconda. We recommend installing in the lab directory, /labs/asbhatt/YOURNAME/miniconda3
```
Then, if you haven't already, set up a Snakemake profile for SCG by following the instructions [here](https://github.com/bhattlab/slurm). 
Then clone this github repository to a place on scg. I keep a 'projects' folder in my home directory for cloning repos.
```
cd ~/projects
git clone git@github.com:bhattlab/bhattlab_workflows.git
cd ~/projects/bhattlab_workflows
```
Then create an environment for your workflow of choice. For example, to start with the preprocessing workflow:

```
conda env create -f envs/preprocessing.yaml
```

## Running the workflow
Using the preprocessing workflow here as an example. You'll have to change options in the configuration file to match where your data lives on SCG, etc.
```
source activate preprocessing
snakemake --configfile ~/projects/bhattlab_workflows/preprocessing/config.yaml -s ~/projects/bhattlab_workflows/preprocessing/preprocessing.snakefile --profile scg
```


# Preprocessing 

To use this pipeline, edit parameters in the config.yaml, and specify the proper path to config file in the submission script.

**The only parameters that need changing in the config file**
1. directory path containing demultiplexed raw fastq files (DATA_DIR)
2. root directory path for output files (PROJECT_DIR)
3. directory path for the host reference genome (BWA index)

*This program runs under the assumption samples are named <sample_id>\_[R]1.fastq[fq].gz and <sample_id>\_[R]2.fastq[fq].gz.* The R1/R2 and suffix must be specified in the config. 

**This script will create the following folders:**
- PROJECT_DIR/01_processing/00_qc_reports/pre_fastqc
- PROJECT_DIR/01_processing/00_qc_reports/post_fastqc
- PROJECT_DIR/01_processing/01_trimmed
- PROJECT_DIR/01_processing/02_dereplicate
- PROJECT_DIR/01_processing/03_sync
- PROJECT_DIR/01_processing/04_host_align
- PROJECT_DIR/01_processing/05_sync


The files that can then be used in downstream analyses will be in PROJECT_DIR/01_processing/05_sync/ as {sample}\_1.fq, {sample}\_2.fq, {sample}\_orphans.fq 

### Reference genomes for removal of host reads
For Bhatt lab purposes, we only conduct experiments on two hosts, humans and mice. You can specify the host reference genomes in the config using the following directories. 
- **Humans:** 
``` /labs/asbhatt/data/host_reference_genomes/hg19/hg19.fa ```
- **Mice:** 
``` /labs/asbhatt/data/host_reference_genomes/mm10/mm10.fa ```

If working on a different cluster or different model organism, these are the steps necessary to build the host reference index for alignment. I am showing the steps used to build Bhatt lab hosts from above using BWA. 

Download reference genomes
```
mkdir -p /labs/asbhatt/data/host_reference_genomes/ # change to preferred directory path
cd /labs/asbhatt/data/host_reference_genomes/ 
wget http://hgdownload.soe.ucsc.edu/goldenPath/hg19/bigZips/hg19.2bit; 
```
Convert to fasta format
```
wget http://hgdownload.cse.ucsc.edu/admin/exe/linux.x86_64/twoBitToFa;
chmod +x twoBitToFa; 
./twoBitToFa hg19.2bit hg19.fa; 
```
Create bowtie index
```
bwa index hg19.fa
```


# Classification and taxonomic barplots
Deprecated. See our [Kraken2](https://github.com/bhattlab/kraken2_classification) github for the most up to date classification workflow.

# Assembly

Assemble preprocessed read data. Launches either Spades or Megahit. Evaluates result with Quast. Accepts an input table, specified in the config.yaml (see example), that looks like this:

```
Sample	Reads1.fq[.gz][,Reads2.fq[.gz][,orphans.fq[.gz]]]
foo	a_1.fq,a_2.fq
bar	b_1.fq,b_2.fq
```

