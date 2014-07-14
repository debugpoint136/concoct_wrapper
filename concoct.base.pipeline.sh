#!/bin/bash


echo "Setting environmental variables.."
export ORGANISM=Crucifer_flea_beetle
export CONCOCT=/import/pool2/home/dpuru/src/CONCOCT
export CONCOCT_TEST=/import/pool2/home/dpuru/src/CONCOCT-test-data-0.3.2
#export CONCOCT_EXAMPLE=/import/pool2/home/dpuru/CONCOCT-complete-example
export MRKDUP=/import/pool2/home/dpuru/src/picard/dist/MarkDuplicates.jar
export PATH=/import/pool2/home/dpuru/src/bedtools2/bin:${PATH}

export CONCOCT_EXAMPLE=/import/assembly/data/Genome_Snapshot/deContaM-blobology/$ORGANISM/concoct/CONCOCT-complete-example

#setenv CONCOCT /import/pool2/home/dpuru/src/CONCOCT
#setenv CONCOCT_TEST /import/pool2/home/dpuru/src/CONCOCT-test-data-0.3.2
#setenv CONCOCT_EXAMPLE /import/pool2/home/dpuru/CONCOCT-complete-example
#setenv MRKDUP /import/pool2/home/dpuru/src/picard/dist/MarkDuplicates.jar
#setenv PATH /import/pool2/home/dpuru/src/bedtools2/bin:${PATH}

echo "Done setting.."
echo "-------------"
echo "working with these values.."

echo $ORGANISM
echo $CONCOCT
echo $MRKDUP
echo $CONCOCT_EXAMPLE

#set the environment to anaconda
cd ~/anaconda/envs
source activate concoct_env

echo "sourced environment successfully!"
echo "below version of python will be used : -"
which python

echo "--------------"
#Cutting up contigs -- ~ 2 min
cd $CONCOCT_EXAMPLE
#python $CONCOCT/scripts/cut_up_fasta.py -c 10000 -o 0 -m contigs/assembly.fa > contigs/assembly_c10K.fa

#convert fastq to fasta
#cat reads/*.1.fastq | awk '{if(NR%4==1) {printf(">%s\n",substr($0,2));} else if(NR%4==2) print;}' > reads/${ORGANISM}_R1.fa &
#cat reads/*.2.fastq | awk '{if(NR%4==1) {printf(">%s\n",substr($0,2));} else if(NR%4==2) print;}' > reads/${ORGANISM}_R2.fa

echo "---#Map the Reads onto the Contigs --"
#bowtie2-build contigs/assembly_c10K.fa contigs/assembly_c10K.fa

#Mark duplicates
#for f in $CONCOCT_EXAMPLE/reads/*_R1.fa; do
#    mkdir -p map/$(basename $f);
#    cd map/$(basename $f);
#    bash $CONCOCT/scripts/map-bowtie2-markduplicates.sh -ct 12 -p '-f' $f $(echo $f | sed s/R1/R2/) pair $CONCOCT_EXAMPLE/contigs/assembly_c10K.fa asm bowtie2;
#    cd ../..;
#done

echo "---#Generate coverage table---"

cd $CONCOCT_EXAMPLE/map

python $CONCOCT/scripts/gen_input_table.py --isbedfiles \
    --samplenames  <(for s in ${ORGANISM}*; do echo $s | cut -d'_' -f1; done) \
    ../contigs/assembly_c10K.fa */bowtie2/asm_pair-smds.coverage \
> concoct_inputtable.tsv

echo "---#Generate linkage table---"

python $CONCOCT/scripts/bam_to_linkage.py -m 8 \
    --regionlength 500 --fullsearch \
    --samplenames <(for s in ${ORGANISM}*; do echo $s | cut -d'_' -f1; done) \
    ../contigs/assembly_c10K.fa */bowtie2/asm_pair-smds.bam \
> concoct_linkage.tsv

mkdir $CONCOCT_EXAMPLE/concoct-input
mv concoct_inputtable.tsv $CONCOCT_EXAMPLE/concoct-input/
mv concoct_linkage.tsv $CONCOCT_EXAMPLE/concoct-input/

echo "---#Run concoct---"

cd $CONCOCT_EXAMPLE
cut -f1,3-26 concoct-input/concoct_inputtable.tsv > concoct-input/concoct_inputtableR.tsv

concoct -c 40 --coverage_file concoct-input/concoct_inputtableR.tsv --composition_file contigs/assembly_c10K.fa -b concoct-output/

echo "---#Evaluate output---"

cd $CONCOCT_EXAMPLE
mkdir evaluation-output
/import/shared/lang/R/R-3.1.0/bin/Rscript $CONCOCT/scripts/ClusterPlot.R -c concoct-output/clustering_gt1000.csv -p concoct-output/PCA_transformed_data_gt1000.csv -m concoct-output/pca_means_gt1000.csv -r concoct-output/pca_variances_gt1000_dim -l -o evaluation-output/ClusterPlot.pdf
