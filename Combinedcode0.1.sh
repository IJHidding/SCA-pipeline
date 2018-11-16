#!/bin/bash

#This links to the relevant datasets # soon config file
#################################INPUTFILES AND DATASETS#######################################################
## move to config file soon
encodedata=/groups/umcg-gdio/tmp04/umcg-ihidding/IWAN/wgEncodeRegTfbsClusteredV3.bed
genexprss=/groups/umcg-gdio/tmp04/umcg-ihidding/IWAN/GTEx_Analysis_2016-01-15_v7_RNASeQCv1.1.8_gene_median_tpm.gct
tissuelist=/groups/umcg-gdio/tmp04/umcg-ihidding/IWAN/tissuelist.txt
Jaspardatafile=/groups/umcg-gdio/tmp04/umcg-ihidding/IWAN/Jasparbed/
Jasparmatrixfile=/groups/umcg-gdio/tmp04/umcg-ihidding/IWAN/Jasparmatrix/
Ensembl=/groups/umcg-gdio/tmp04/umcg-ihidding/IWAN/Ensembler_lexi


###############################################################################################################
#These functions call the help and information for users. 
#It also gives a list of the available tissue types.
###################################HELP AND INFORMATION########################################################

function showHelp() {
        #
        # Display commandline help on STDOUT.
        #
	cat <<EOH
===============================================================================================================
Script to analyze variants in transcription factor binding sites.
Usage:
	sh $(basename $0) OPTIONS
Options:
	-h	Show this help.

	Required:
	-i	inputfile(.vcf)

	Optional:
	-t	Specific tissuetypes for expression data.
	-l	Show available tissuetypes.

Output will be written in ./IWAN_output
===============================================================================================================
EOH
	trap - EXIT
        exit 0
}

function TissueList () {
	cat <<tissuelist
===============================================================================================================
This is a list of all available tissue expression data.
Usage:
        Add the number(s) of the tissues to the commandline comma separated.
	-t 1,2,3..
Options:
	1	Adipose - Subcutaneous
	2	Adipose - Visceral (Omentum)
	3	Adrenal Gland
	4	Artery - Aorta
	5	Artery - Coronary
	6	Artery - Tibial
	7	Bladder
	8	Brain - Amygdala
	9	Brain - Anterior cingulate cortex (BA24)
	10	Brain - Caudate (basal ganglia)
	11	Brain - Cerebellar Hemisphere
	12	Brain - Cerebellum
	13	Brain - Cortex
	14	Brain - Frontal Cortex (BA9)
	15	Brain - Hippocampus
	16	Brain - Hypothalamus
	17	Brain - Nucleus accumbens (basal ganglia)
	18	Brain - Putamen (basal ganglia)
	19	Brain - Spinal cord (cervical c-1)
	20	Brain - Substantia nigra
	21	Breast - Mammary Tissue0
	22	Cells - EBV-transformed lymphocytes
	23	Cells - Transformed fibroblasts
	24	Cervix - Ectocervix
	25	Cervix - Endocervix
	26	Colon - Sigmoid
	27	Colon - Transverse
	28	Esophagus - Gastroesophageal Junction
	29	Esophagus - Mucosa
	30	Esophagus - Muscularis
	31	Fallopian Tube
	32	Heart - Atrial Appendage
	33	Heart - Left Ventricle
	34	Kidney - Cortex 
	35	Liver
	36	Lung
	37	Minor Salivary Gland
	38	Muscle - Skeletal
	39	Nerve - Tibial
	40	Ovary
	41	Pancreas
	42	Pituitary
	43	Prostate
	44	Skin - Not Sun Exposed (Suprapubic)
	45	Skin - Sun Exposed (Lower leg)
	46	Small Intestine - Terminal Ileum
	47	Spleen 
	48	Stomach
	49	Testis
	50	Thyroid
	51	Uterus
	52	Vagina
	53	Whole Blood

===============================================================================================================
tissuelist
        trap - EXIT
        exit 0
}


###############################################################################################################
#This function does the main analysis, it compares the variants with known transcription factor binding sites,
#Then it takes the corresponding matrix and calculates a score that gives an indication of the predicted effect
#of the variant. It also determines the closest gene to the site in an attempt to indicate both the gene and the
#transcription factor.  
##############################ANALYSISSCRIPT###################################################################

function Analysis_script () {
	local inputfile=$1
	local header=$2

	bedtools sort -i $inputfile > ${tmpdir}tmp && mv ${tmpdir}tmp $inputfile
	cat $header $inputfile > ${tmpdir}bedtoolsfile.vcf
	local filename=$(basename -- "$file")
	local filenamefile="${filename%.*}"

	for f in ${Jaspardatafile}MA*; do
	        local filename=$(basename -- "$f")
		local filename="${filename%.*}"
### Can be done in one line with basename $f .txt(?)

		bedtools intersect -wa -a ${tmpdir}bedtoolsfile.vcf -wb -b $f > ${tmpdir}${filename}_output.tmp
		if [ -s ${tmpdir}${filename}_output.tmp ];
		then
	                while IFS='' read -r line || [[ -n "$line" ]]; do
	        
		                local columnstartpos=$((numberofcolumns + 2))
	                        local columnstartposneg=$((numberofcolumns + 3))
	                        local columnposstring=$(( numberofcolumns + 6 ))
	                        local posornegstring=$( echo $line | awk -v PosorNeg="$columnposstring" '{ print $PosorNeg}' )
	      
		                if [ "$posornegstring" == "-" ]
	                        then
	                                local MutationLocation=$(echo "$line" | awk -v val=$columnstartposneg '{ print $val-$2+2}')
	                        else
	                                local MutationLocation=$(echo "$line" | awk -v val=$columnstartpos '{ print $2-$val+1}')
	                        fi

	                        if [ "$MutationLocation" -eq 1 ] ; then continue ; fi
				local line="${line} ${filename}"
	                        local Matrixfile=${Jasparmatrixfile}${filename}.jaspar
	                        local Matrixgenename=$(sed '5q;d' $Matrixfile)

	                        local sumofmatrix=$(awk '{s+=$2}END{print s}' $Matrixfile)
	                        local valueofmut=$(echo $line | cut -d' ' -f5)
	                        local valueoforiginal=$(echo $line | cut -d' ' -f4)

	                        if [ $(echo $valueofmut | wc -m) -gt 2 ] || [ $(echo $valueoforiginal | wc -m) -gt 2 ]
	                        then
	
	                                local line="${line} . . ${Matrixgenename}"
	                                echo $line >> ${tmpdir}output.txt
				else
	                                local Columntobeadded=$(awk -v MutLoc="$MutationLocation" '{ print $1 $MutLoc }' $Matrixfile)
	                                if [ "$posornegstring" == "-" ]
	                                then
	                                        local valueofmut=$( echo "$valueofmut" | tr ACGT TGCA )
	                                        local valueoforiginal=$( echo "$valueoforiginal" | tr ACGT TGCA )
	                                fi

	                                local valofmut=$( echo "$valueofmut" | tr ACGT 1234 )
	                                local valoforiginal=$( echo "$valueoforiginal" | tr ACGT 1234 )

	                                local Newval=$(awk -v MutLoc=$MutationLocation -v Val=$valofmut 'FNR == Val {print $MutLoc}' $Matrixfile)
	                                local Oldval=$(awk -v MutLoc=$MutationLocation -v Val=$valoforiginal 'FNR == Val {print $MutLoc}' $Matrixfile)

	                                if [ -z "$Newval"  ]; then continue ; fi

	                                local Newvalue=$(echo "scale=10 ; $Newval / $sumofmatrix + 0.001" | bc)
	                                local Oldvalue=$(echo "scale=10 ; $Oldval / $sumofmatrix + 0.001" | bc)
	                                local totalvalueofmutation=$(echo "scale=10 ; $Oldvalue / $Newvalue" | bc)
#potentially not needed
					local totvalueofmutation=${totalvalueofmutation/.*}
	                                
					if [[ "$totvalueofmutation" -ge 1 ]]
	                                then
	                                        local newmutationvalue=$(echo "scale=2 ; $totalvalueofmutation / 1" | bc)
	                                else
	                                        local newmutationvalue=$(echo "scale=2 ; -1 / $totalvalueofmutation" | bc)
	                                fi
					local Combinedcolumn="$(echo $Columntobeadded | tr ' ' ':' )"
	                                local Combinedcolumnfix="$(echo $Combinedcolumn | cut -d':' -f1-4 )"
	
	                                local line="${line} ${Combinedcolumnfix} ${newmutationvalue} ${Matrixgenename}"
	
	                                echo $line >> ${tmpdir}output.txt
	                        fi
	                done < ${tmpdir}${filename}_output.tmp
	        fi
	done


	tr ' ' \\t < ${tmpdir}output.txt > ${tmpdir}tmp && mv ${tmpdir}tmp ${tmpdir}output.txt
	sed -i '1{/^[[:space:]]*$/d}' ${tmpdir}output.txt
	bedtools sort -i ${tmpdir}output.txt > ${tmpdir}tmp && mv ${tmpdir}tmp ${tmpdir}output.txt
	cat $header ${tmpdir}output.txt > ${tmpdir}tmp && mv ${tmpdir}tmp  ${tmpdir}output.vcf
	bedtools closest -wb -b $Ensembl -a ${tmpdir}output.vcf -t last > ${tmpdir}Genelist.tmp
	local columnofstartpos=$((numberofcolumns+12))
	local columnofgenes=$((numberofcolumns+15))
	cut -d$'\t' -f${columnofstartpos},${columnofgenes} ${tmpdir}Genelist.tmp > ${tmpdir}genelistfile.tmp
	paste ${tmpdir}output.txt ${tmpdir}genelistfile.tmp > ${tmpdir}tmp && mv ${tmpdir}tmp ${tmpdir}output.txt




}
###############################################################################################################
#Because the JASPAR database consists of predicted binding sites this function is used to validate the found 
#binding sites up to a certain level. It compares the found sites with known chip-seq data for proteins found
#within a certain region. This gives an indication whether or not the site can be a real binding site.   
#The found site is compared with the encode database to see if in that region the transcription factor has been 
#found aswell. 
##########################################VALIDATIONSCRIPT#####################################################
function Validation_script () {

	local input=$1
	local header=$2

	cat $header $input > ${tmpdir}filewithheader.vcf

	bedtools intersect -a ${tmpdir}filewithheader.vcf -wb -b $encodedata > ${tmpdir}encodedatafile.tmp

	rm ${tmpdir}filewithheader.vcf

	local columnfoundsite=$((numberofcolumns+10))
	local columnvalidatedsite=$((numberofcolumns+16))
	while read -r line || [[ -n "$line" ]]; do
	        local Foundsite=$(echo $line | cut -d$' ' -f${columnfoundsite})
	        local Validatedsite=$(echo $line | cut -d$' ' -f${columnvalidatedsite})
	        if [ $Foundsite == $Validatedsite ]
	        then
	                local line="${line}   Validated"
	                echo $line >> ${tmpdir}validated_output.tmp
#	        else
#			local line="${line}   ."
#	                echo $line >> ${tmpdir}nonvalidated_output.tmp
	        fi
	done < ${tmpdir}encodedatafile.tmp

#	for pos in $(cut -d$'\t' -f2 $input); do
#	        grep $pos ${tmpdir}nonvalidated_output.tmp > ${tmpdir}nonval.tmp
#	        local val=$(grep $pos ${tmpdir}validated_output.tmp)
#	        if [ -z "$val" ]
#	        then
#	                head -1 ${tmpdir}nonval.tmp >>  ${tmpdir}nonvalidated.tmp
#		fi	
#	done

#	cat ${tmpdir}validated_output.tmp ${tmpdir}nonvalidated.tmp > ${tmpdir}Combined_output.tmp
#	tr ' ' \\t < ${tmpdir}Combined_output.tmp > ${tmpdir}validatedMain.tmp

	tr ' ' \\t < ${tmpdir}validated_output.tmp > ${tmpdir}validatedMain.tmp
	awk '!x[$0]++' ${tmpdir}validatedMain.tmp > ${tmpdir}output.txt
 
}

###############################################################################################################
#If indicated this script will analyse the indicated tissuetypes for each gene and transcription factor found
#this will return expression data per tissue per gene from the GTEx database.
#
######################################TISSUETYPES##############################################################

function Tissue_types () {

	input=$2
	tissuetypes=$1

	local columnwithgenename=$((numberofcolumns + 12))
	local columnwithTFgenename=$((numberofcolumns + 10))

	for number in $( echo $tissuetypes | sed 's/,/ /g' ); do
	        local numb=$(($number+2))
	        local tissue=$(awk -v var=$numb 'NR==var' $tissuelist)
	        for gene in $(cut -d$'\t' -f${columnwithgenename} $input); do
	                grep  $'\t'${gene}$'\t' $genexprss | cut -d$'\t' -f${numb} > ${tmpdir}geneexpressionvalue.tmp
	                sed "s/^/${tissue}=/" ${tmpdir}geneexpressionvalue.tmp >> ${tmpdir}geneexprssval.tmp
	        done

	        if [ -f ${tmpdir}Geneexprssval.tmp ];
	        then
	                paste ${tmpdir}Geneexprssval.tmp ${tmpdir}geneexprssval.tmp > ${tmpdir}tmp && mv ${tmpdir}tmp ${tmpdir}Geneexprssval.tmp
	        else
	                paste ${tmpdir}geneexprssval.tmp > ${tmpdir}Geneexprssval.tmp
	        fi

	        tr '\t' '/' < ${tmpdir}Geneexprssval.tmp > ${tmpdir}tmp && mv ${tmpdir}tmp ${tmpdir}Geneexprssval.tmp
	        rm ${tmpdir}geneexprssval.tmp
	        for gene in $(cut -d$'\t' -f${columnwithTFgenename} $input); do
	                grep  $'\t'${gene}$'\t' $genexprss | cut -d$'\t' -f${numb} > ${tmpdir}genebindexpressionvalue.tmp
	                sed "s/^/TF${tissue}=/" ${tmpdir}genebindexpressionvalue.tmp  >> ${tmpdir}genebindexprssval.tmp
	        done

	        if [ -f ${tmpdir}Genebindexprssval.tmp ];
	        then
	                paste ${tmpdir}Genebindexprssval.tmp ${tmpdir}genebindexprssval.tmp > ${tmpdir}tmp && mv ${tmpdir}tmp ${tmpdir}Genebindexprssval.tmp
	        else
	                paste ${tmpdir}genebindexprssval.tmp > ${tmpdir}Genebindexprssval.tmp
	        fi
	        tr '\t' '/' < ${tmpdir}Genebindexprssval.tmp > ${tmpdir}tmp && mv ${tmpdir}tmp ${tmpdir}Genebindexprssval.tmp
	        rm ${tmpdir}genebindexprssval.tmp
	done

	paste ${tmpdir}Genebindexprssval.tmp ${tmpdir}Geneexprssval.tmp > ${tmpdir}combinedexprssval.tmp
	paste $input ${tmpdir}combinedexprssval.tmp > ${tmpdir}tmp && mv ${tmpdir}tmp ${tmpdir}output.txt

}

###############################################################################################################
#This function removes any duplicated lines formed by earlier functions, specifically when a single variant has
#been found within overlapping binding sites. It also culls any columns added by previous functions that add 
#duplicate data. ##potentially add this to the end of every function for increased adapability##
#####################################DUPLICATIONFIX############################################################

function Duplication_fix () {

	input=$1

	awk '{print NF}' $input | sort -nu | tail -n 1 > ${tmpdir}numberofcolumnsinfile.tmp
	local numberofcolumnsinfile=$(cat ${tmpdir}numberofcolumnsinfile.tmp)

	for dup in $(cut -d$'\t' -f2 $input | sort -m | uniq -d); do
	        grep $dup $input > ${tmpdir}line.tmp
	        local numberoflines=$(wc -l < ${tmpdir}line.tmp)
	        local Addedcolumns=""
	        for column in $(seq ${numberofcolumnsinfile}); do
	                local Column=$(cut -d$'\t' -f${column} ${tmpdir}line.tmp)

	                local var1=$(echo $Column | cut -d$' ' -f1)
	                local var2=$(echo $Column | cut -d$' ' -f2)
	                if [ "$var1" == "$var2" ]; then local Combined=$var1 ; else local Combined="$var1/$var2" ; fi
#	                then
#	                        local Combined=$var1
#	                else
#	                        local Combined="$var1/$var2"
#	                fi

	                local Addedcolumns="${Addedcolumns} ${Combined}"
	
	        done
	        echo $Addedcolumns >> ${tmpdir}duplicatedline.tmp
	done
	
	
	for nodup in $(cut -d$'\t' -f2 $input | sort -m |  uniq -u); do
	        grep $nodup $input >> ${tmpdir}noduplicatedlines.tmp
	done
	
	
	cat ${tmpdir}duplicatedline.tmp ${tmpdir}noduplicatedlines.tmp > ${tmpdir}output.txt
	tr ' ' \\t < ${tmpdir}output.txt > ${tmpdir}tmp && mv ${tmpdir}tmp ${tmpdir}output.txt
	
	local column1=$((numberofcolumns+4))
	local column2=$((numberofcolumns+7))
	local column3=$((numberofcolumns+12))
	local column4=$((numberofcolumns+21))
	cut -d$'\t' -f${column1},${column2}-${column3},${column4}- ${tmpdir}output.txt | tr '\t' '|' > ${tmpdir}tempoutput.tmp
	cut -d$'\t' -f1-${numberofcolumns} ${tmpdir}output.txt > ${tmpdir}input.tmp
	paste ${tmpdir}input.tmp ${tmpdir}tempoutput.tmp > ${tmpdir}output.txt

}

###############################################################################################################
#This function adds the newly made lines back to the file by removing the lines that were annotated from the input
#and adding the annotated lines. It also sorts the data and adds the header back on top.
#
#####################################OUTPUTSHARE###############################################################

function Output_share () {

	wholefile=$1
	header=$2

	sed 's/chr//' $input | sort -m > ${tmpdir}tmp && mv ${tmpdir}tmp ${tmpdir}output.txt
	cut -d$'\t' -f1,2 ${tmpdir}output.txt > ${tmpdir}excludefile.tmp
	grep -v -f ${tmpdir}excludefile.tmp $wholefile > ${tmpdir}excludedfile.tmp
	cat  ${tmpdir}excludedfile.tmp ${tmpdir}output.txt > ${tmpdir}tmp && mv ${tmpdir}tmp ${tmpdir}output.txt
	sed 's/chr//' $input | sort > ${tmpdir}tmp && mv ${tmpdir}tmp ${tmpdir}output.txt
	cat $header ${tmpdir}output.txt > ${output}${InputnameNoExtention}_output.vcf

}

###############################################################################################################
#The main analysis the input, sorts the data and calls all the functions.
#
#
########################################MAIN###################################################################

while getopts "i:r:h:l" opt;
do
        case $opt in h)showHelp;; i)input="${OPTARG}";; t)tissue="${OPTARG}";; l)TissueList;;
        esac
done

if [[ -z "${input:-}" ]]; then showHelp ; echo "No input is given" ; fi

output="IWAN_output/"
tmpdir="IWAN_output/tmp/"

#Creating tmp and output directories to store created files.
if [ ! -d "$output" ]; then mkdir IWAN_output ; fi
if [ ! -d "$tmpdir" ]; then mkdir IWAN_output/tmp ; fi

module load BEDTools


#This will store the file in the input folder as to leave the original input file intact.

filename=$(basename -- "$input")
InputnameNoExtention="${filename%.*}"

#This will check if the file is compressed and it will decompress if needed.
if [[ $input =~ \.t?gz$ ]];
then
        echo "Unzipping data.."
        cp $input ${tmpdir}
        mv ${tmpdir}$filename ${tmpdir}inputfile.vcf.gz
        gunzip ${tmpdir}inputfile.vcf.gz
else
        cp $input ${tmpdir}
        mv ${tmpdir}$filename ${tmpdir}inputfile.vcf
fi

fixedinput=${tmpdir}inputfile.vcf


#Here the header is stored in a file to be added back to the file in later stages.
echo "Analyzing input.."
grep '#' $fixedinput > ${tmpdir}header.txt

#Here the all the data without the header is taken from the file and "chr" is added infront of the chromosome number as it is required by certain databases.
grep -v '#'  $fixedinput > ${tmpdir}filenoheader.txt
grep -v '#'  $fixedinput | grep -v 'protein_coding' | tr ' ' '_' > ${tmpdir}startfile.txt
grep -v '#' $fixedinput | grep '5_prime_UTR'  | tr ' ' '_' >> ${tmpdir}startfile.txt

grep 'chr' $fixedinput > ${tmpdir}test.tmp
if [ -s ${tmpdir}test.tmp ];
then
        :
else

        sed -i 's/^/chr/' ${tmpdir}startfile.txt
fi


#sed -i 's/^/chr/' ${tmpdir}startfile.txt

#This takes the total number of columns in the file to ensure no problems when files have different number of columns.
awk '{print NF}' ${tmpdir}startfile.txt | sort -nu | tail -n 1 > ${tmpdir}numberofcolumns.tmp
numberofcolumns=$(cat ${tmpdir}numberofcolumns.tmp)


echo "Starting analysis.."

Analysis_script ${tmpdir}startfile.txt  ${tmpdir}header.txt

#This loads the validationscript
echo "Validating analysis.."
Validation_script ${tmpdir}output.txt ${tmpdir}header.txt

#This checks if there are any tissues indicated and will run the tissues script for additional annotation.
if [ -z "$tissue" ]
then
        echo "No tissues assigned.."
else
        echo "Adding tissue data.."
        Tissue_types $tissue ${tmpdir}output.txt
fi


#This starts the duplication fix script to remove additional lines.
echo "Fixing duplicated lines.."
Duplication_fix ${tmpdir}output.txt


#This recombines the found variants with the input file and stores it in a new output file.
echo "Adding info to input file.."
Output_share ${tmpdir}filenoheader.txt ${tmpdir}header.txt

#This clears the tmp directory and removes any leftover .txt files it also shows the modules currently loaded.
rm ${tmpdir}/*
module list

echo "Analysis completed, have a nice day!"

###############################################################################################################

#######################################FINISHING UP############################################################

## deleting files created in the program.

rm -rf $tmpdir
###############################################################################################################
