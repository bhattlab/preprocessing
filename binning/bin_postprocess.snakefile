from os.path import join, abspath, expanduser, exists
localrules: postprocess, combine_final_reports

# separating the postprocessing part out into a separate file
# this assumes that all necessary files have been generated by the snakemake pipeline already
# and all that has to be done is combining them into one
# uses the same configfile as the standard binning manysamp

def get_sample_assemblies_reads(sample_file):
    sample_reads = {}
    sample_assemblies = {}
    with open(sample_file) as sf:
        for l in sf.readlines():
            s = l.strip().split("\t")
            if len(s) == 1 or s[0] == 'Sample' or s[0] == '#Sample' or s[0].startswith('#'):
                continue
            if len(s) < 3:
                sys.exit('Badly formatted sample_file')
            sample = s[0]
            assembly = s[1]
            reads_split = s[2].split(',')
            if sample in sample_reads:
                print(sample)
                raise ValueError("Non-unique sample encountered!")
            # get read pairs and singles from read specification
            if (len(reads_split) == 3) or (len(reads_split) == 2):
                sample_reads[sample] = reads_split[0:2]
            elif len(reads_split)==1:
                sample_reads[sample] = reads_split[0]
                # sys.exit('must be paired end reads')
            sample_assemblies[sample] = assembly
    return sample_reads, sample_assemblies

# Read in sample and outdir from config file
sample_file = config['sample_file']
outdir = config['outdir_base']
sample_reads, sample_assemblies = get_sample_assemblies_reads(sample_file)
sample_list = list(sample_reads.keys())

# convert outdir to absolute path
if outdir[0] == '~':
    outdir = expanduser(outdir)
outdir = abspath(outdir)


print('##################################################################')
print(' SAMPLE LIST ')
print(sample_list)
print('##################################################################')
print('##################################################################')
print(' ONLY CONDUCTING POSTPROCESSING STEPS ')
print('##################################################################')

def get_DAStool_bins(wildcards):
    outputs = join(outdir, wildcards.sample, "DAS_tool_bins")
    bins = glob_wildcards(join(outputs, "{bin}.fa")).bin
    return bins

rule all:
    input:
        # Post-processing
        expand(join(outdir, "{sample}/classify/bin_species_calls.tsv"), sample = sample_list),
        expand(join(outdir, "{sample}/final/{sample}.tsv"), sample = sample_list),
        expand(join(outdir, "{sample}/final/{sample}_simple.tsv"), sample = sample_list),
        join(outdir, "binning_table_all_full.tsv"),

rule postprocess:
    input:
        prokka = lambda wildcards: expand(join(outdir, "{sample}/prokka/{bin}.fa/{sample}_{bin}.fa.gff"), bin = get_DAStool_bins(wildcards), sample = wildcards.sample),
        quast = lambda wildcards: expand(join(outdir, "{sample}/quast/{bin}.fa/report.tsv"), bin = get_DAStool_bins(wildcards), sample = wildcards.sample),
        checkm = join(outdir, "{sample}/DAS_tool/checkm/checkm.tsv"),
        trna = lambda wildcards: expand(join(outdir, "{sample}/rna/trna/{bin}.fa.txt"), bin = get_DAStool_bins(wildcards), sample = wildcards.sample),
        rrna = lambda wildcards: expand(join(outdir, "{sample}/rna/rrna/{bin}.fa.txt"), bin = get_DAStool_bins(wildcards), sample = wildcards.sample),
        classify = join(outdir, "{sample}/classify/bin_species_calls.tsv"),
        coverage = lambda wildcards: expand(join(outdir, "{sample}/coverage/{bin}.txt"), bin = get_DAStool_bins(wildcards), sample = wildcards.sample),
    output:
        full = join(outdir, "{sample}/final/{sample}.tsv"),
        simple = join(outdir, "{sample}/final/{sample}_simple.tsv")
    singularity:
        "shub://bsiranosian/bin_genomes:binning"
    params:
        # prokka = lambda wildcards: prokka_file_dict[wildcards.sample],
        bins = lambda wildcards: get_DAStool_bins(wildcards),
        sample = lambda wildcards: wildcards.sample
    script: 
        "scripts/postprocess.R"

rule combine_final_reports:
    input:
        all_full = expand(join(outdir, "{sample}/final/{sample}.tsv"), sample=sample_list),
        single_full = expand(join(outdir, "{sample}/final/{sample}.tsv"), sample=sample_list[0]),
        all_simple = expand(join(outdir, "{sample}/final/{sample}_simple.tsv"), sample=sample_list),
        single_simple = expand(join(outdir, "{sample}/final/{sample}_simple.tsv"), sample=sample_list[0]),
    output:
        full = join(outdir, "binning_table_all_full.tsv"),
        simple = join(outdir, "binning_table_all_simple.tsv"),
    shell: """
        head -n 1 {input.single_full} > {output.full}
        tail -n +2 -q {input.all_full} >> {output.full}
        head -n 1 {input.single_simple} > {output.simple}
        tail -n +2 -q {input.all_simple} >> {output.simple}
    """
