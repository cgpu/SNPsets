// minimumN_value; Request in script with params.minimumN_value since no channel will be made
if (!params.minimumN_value){
    exit 1, "--minimumN_value not found, please specify an integer from 1 to N of vcf files you provide in --inputdir: ${params.inputdir}" 
}

// inputdir: retrieve vcf
Channel.fromPath("${params.inputdir}/*.vcf")
        .ifEmpty { exit 1, "--inputdir  not found or is missing required .vcf files" }
        .collect()
        .set { vcf_for_create_union_vcf  }

// inputdir: retrieve idx
Channel.fromPath("${params.inputdir}/*.idx")
        .ifEmpty { exit 1, "--inputdir not found or is missing required .idx files" }
        .collect()
        .set { idx_vcf_for_create_union_vcf  }

// fasta
Channel.fromPath(params.fasta)
       .ifEmpty { exit 1, "fasta annotation file not found: ${params.fasta}" }
       .set { fasta_for_create_union_vcf }

// fai
Channel.fromPath(params.fai)
       .ifEmpty { exit 1, "fasta index file not found: ${params.fai}" }
       .set {  fai_for_create_union_vcf  }


// dict
Channel.fromPath(params.dict)
       .ifEmpty { exit 1, "dict annotation file not found: ${params.dict}" }
       .set { dict_for_create_union_vcf }

// range of values of minimumN_value
// Java Collection; collection entries will be emitted as individual values
def minimumN_value_integer = (params.minimumN_value).toInteger()

Channel.from( 1..minimumN_value_integer )
       .into { minimumN_value_range_channel ; minimumN_value_range_channel_to_check}

minimumN_value_range_channel_to_check


vcf_and_idx_channel = vcf_for_create_union_vcf.combine(idx_vcf_for_create_union_vcf)
minN_vcf_idx_combined_channel = minimumN_value_range_channel.combine(vcf_and_idx_channel)

minN_vcf_idx_combined_channel.into{minN_vcf_idx_combined_channel_to_use ; minN_vcf_idx_combined_channel_to_inspect}

minN_vcf_idx_combined_channel_to_inspect.map{ it ->  tuple(it[0], it[1..-1])  }.view()

process create_union_vcf {

    tag "max minimumN = $params.minimumN_value"
    container "broadinstitute/gatk3:3.8-1"
    publishDir "${params.outdir}/SNPsets", mode: 'copy'
    echo true

    input:
    set val(minN_value), file(all_the_vcfs) from minN_vcf_idx_combined_channel_to_use
    each file(fasta) from fasta_for_create_union_vcf
    each file(fai) from fai_for_create_union_vcf
    each file(dict) from dict_for_create_union_vcf

    output:
    file("unionVCF_SNPpresent_in_at_least*") into union_vcf_channel

    shell:
    '''
    minN_value=$(echo !{minN_value})
    echo -n "java -jar /usr/GenomeAnalysisTK.jar -T CombineVariants -R !{fasta} --minimumN ${minN_value} -genotypeMergeOptions UNIQUIFY " > combine_variants.sh
    for vcf in $(ls *.vcf); do
    echo -n "--variant:$(basename $vcf | cut -d. -f1) $vcf  " >> combine_variants.sh
    done
    echo -n "-o 'unionVCF_SNPpresent_in_at_least_${minN_value}.vcf' "  >> combine_variants.sh
    chmod ugo+xr combine_variants.sh
    bash combine_variants.sh &> log_minN_${minN_value}.txt
    chmod -R ugo+xrw "unionVCF_SNPpresent_in_at_least_${minN_value}.vcf"
    '''
}

