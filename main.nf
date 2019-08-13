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

process create_union_vcf {

    tag "$params.minimumN_value"
    container "broadinstitute/gatk3:3.8-1"
    echo true

    input:
    file(vcf) from vcf_for_create_union_vcf.collect()
    file(idx_vcf) from idx_vcf_for_create_union_vcf.collect()
    file(fasta) from fasta_for_create_union_vcf
    file(fai) from fai_for_create_union_vcf
    file(dict) from dict_for_create_union_vcf

    output:
    file("unionVCF_SNPpresent_in_at_least_.vcf") into union_vcf_channel

    shell:
    '''
    echo -n "java -jar /usr/GenomeAnalysisTK.jar -T CombineVariants -R !{fasta}  -o unionVCF_SNPpresent_in_at_least_.vcf --minimumN !{params.minimumN_value} " > combine_variants.sh
    for vcf in $(ls *.vcf); do
    echo -n "--variant:$(basename $vcf) $vcf " >> combine_variants.sh
    done
    chmod ugo+xr combine_variants.sh
    cat combine_variants.sh
    chmod -R ugo+xrw unionVCF_SNPpresent_in_at_least_.vcf
    '''
}

