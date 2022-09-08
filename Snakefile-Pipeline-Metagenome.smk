import pandas as pd
from snakemake.utils import validate, min_version
from multiprocessing import cpu_count
import glob
import re
import os, sys
import yaml

from snakemake.remote.HTTP import RemoteProvider as HTTPRemoteProvider

HTTP = HTTPRemoteProvider()
shell.executable("bash")

##### Metagenome Snakemake Pipeline              #####
##### Daniel Fischer (daniel.fischer@luke.fi)    #####
##### Natural Resources Institute Finland (Luke) #####

##### Version: 0.1.1
version = "0.1.1"

##### set minimum snakemake version #####
min_version("6.0")

##### load config and sample sheets #####

samplesheet = pd.read_table(config["samplesheet"]).set_index("rawsample", drop=False)
rawsamples=list(samplesheet.rawsample)
samples=list(set(list(samplesheet.sample_name)))  # Unique list
lane=list(samplesheet.lane)

workdir: config["project-folder"]

##### Complete the input configuration
config["host-dict"] = os.path.splitext(config["host"])[0]+".dict"
config["host-fai"] =  config["host"]+".fai"
config["host-index"] = config["host"]+".amb"
config["report-script"] = config["pipeline-folder"]+"/scripts/workflow-report.Rmd"

wildcard_constraints:
    rawsamples="|".join(rawsamples),
    samples="|".join(samples)

##### Extract the cluster resource requests from the server config #####
cluster=dict()
if os.path.exists(config["server-config"]):
    with open(config["server-config"]) as yml:
        cluster = yaml.load(yml, Loader=yaml.FullLoader)

##### input checks #####

# rawdata-folder needs to end with "/", add it if missing:
if config["rawdata-folder"][-1] != '/':
   config["rawdata-folder"]=config["rawdata-folder"]+'/'

# project-folder should not end with "/", so remove it
if config["project-folder"][-1] == '/':
   config["project-folder"]=config["project-folder"][:-1]

##### input function definitions ######

def get_fastq_for_concatenating_read1(wildcards):
    r1 = samplesheet.loc[samplesheet["sample_name"] == wildcards.samples]["read1"]
    path = config["rawdata-folder"]
    output = [path + x for x in r1]
    return output   

def get_fastq_for_concatenating_read2(wildcards):
    r1 = samplesheet.loc[samplesheet["sample_name"] == wildcards.samples]["read2"]
    path = config["rawdata-folder"]
    output = [path + x for x in r1]
    return output  

##### Deriving runtime paramteres ######
if config["starbase"] == "":
    config["starbase"] = os.path.dirname(config["host"])+"/STAR"

config["host-index"] = config["starbase"]+"/Host"

##### Print some welcoming summary #####

##### Print the welcome screen #####
print("#################################################################################")
print("##### Welcome to the Metagenome pipeline")
print("##### version: "+version)
print("##### Number of rawsamples : "+str(len(rawsamples)))
print("##### Number of samples    : "+str(len(samples)))
print("##### Rawdata folder       : "+config["rawdata-folder"])
print("##### Project folder       : "+config["project-folder"])
print("##### Host genome          :" +config["host"])
print("##### Starbase             :" +config["starbase"])
print("#####")

##### run complete pipeline #####

rule all:
    input:
      expand("%s/BAM/{samples}.bam" % (config["project-folder"]), samples=samples),
      "%s/FASTQ/MERGED/all_merged_R1.fastq.gz" % (config["project-folder"]),
      "%s/FASTQ/MERGED/all_merged_R2.fastq.gz" % (config["project-folder"]),
      "%s/MEGAHIT/final.contigs.fa" % (config["project-folder"]),
      expand("%s/BAM/megahit/{samples}_mega.bam" % (config["project-folder"]), samples=samples)

rule preparations:
    input:

rule trimming:
    input:
      expand("%s/BAM/{samples}.bam" % (config["project-folder"]), samples=samples)
      
rule qc:
    input:
      expand("%s/QC/RAW/{rawsamples}_R1_001_fastqc.zip" % (config["project-folder"]), rawsamples=rawsamples),
      expand("%s/QC/RAW/{rawsamples}_R2_001_fastqc.zip" % (config["project-folder"]), rawsamples=rawsamples),
      expand("%s/QC/TRIMMED/{rawsamples}_R1_fastqc.zip" % (config["project-folder"]), rawsamples=rawsamples),
      expand("%s/QC/TRIMMED/{rawsamples}_R2_fastqc.zip" % (config["project-folder"]), rawsamples=rawsamples)

rule alignment:
    input:

### setup report #####
report: "report/workflow.rst"

##### load rules #####
include: "rules/Step1-Preparations.smk"
include: "rules/Step2-ReadProcessing.smk"
include: "rules/Step3-CreateMetagenome.smk"
#include: "rules/Step3-QC.smk"
#include: "rules/Step4-Alignment.smk"
