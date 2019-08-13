// minimumN_value; Request in script with params.minimumN_value since no channel will be made
if (!params.minimumN_value){
    exit 1, "--minimumN_value not found, please specify an integer from 1 to N of vcf files you provide in --inputdir: ${params.inputdir}" 
}

// inputdir: retrieve vcf
Channel.fromPath("${params.inputdir}/*.vcf")
        .ifEmpty { exit 1, "--inputdir  not found or is missing required .vcf files" }
        .set { vcf_for_create_union_vcf  }

// inputdir: retrieve idx
Channel.fromPath("${params.inputdir}/*.idx")
        .ifEmpty { exit 1, "--inputdir not found or is missing required .idx files" }
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

// dict
Channel.from(1..params.dict)
       .ifEmpty { exit 1, "dict annotation file not found: ${params.dict}" }
       .set { dict_for_create_union_vcf }

// range of values of minimumN_value
// Java Collection; collection entries will be emitted as individual values
Channel.from( [1..params.minimumN_value.toInteger()] )
       .set { minimumN_value_range_channel }

process create_union_vcf {

    tag "max minimumN = $params.minimumN_value"
    container "broadinstitute/gatk3:3.8-1"
    publishDir "${params.outdir}/SNPsets", mode: 'copy'

    input:
    file(vcf) from vcf_for_create_union_vcf.collect()
    file(idx_vcf) from idx_vcf_for_create_union_vcf.collect()
    file(fasta) from fasta_for_create_union_vcf
    file(fai) from fai_for_create_union_vcf
    file(dict) from dict_for_create_union_vcf
    val(minimumN_value) from minimumN_value_range_channel

    output:
    file("unionVCF_SNPpresent_in_at_least_!{params.minimumN_value}.vcf") into union_vcf_channel

    shell:
    '''
    echo -n "java -jar /usr/GenomeAnalysisTK.jar -T CombineVariants -R !{fasta} --minimumN !{params.minimumN_value} " > combine_variants.sh
    for vcf in $(ls *.vcf); do
    echo -n "--variant:$(basename $vcf | cut -d. -f1) $vcf  " >> combine_variants.sh
    done
    echo -n "-o unionVCF_SNPpresent_in_at_least_!{params.minimumN_value}.vcf"  >> combine_variants.sh
    chmod ugo+xr combine_variants.sh
    bash combine_variants.sh
    chmod -R ugo+xrw unionVCF_SNPpresent_in_at_least_!{params.minimumN_value}.vcf
    '''
}

