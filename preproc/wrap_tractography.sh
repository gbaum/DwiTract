#!/bin/sh

#################################################################
### Define subject list in 'bblid_scanid_dateidofscan' format ###
#################################################################
subject_list=$(cat /data/joy/BBL/projects/pncBaumDti/n2416_tractography_pipeline/subjects/n1722_subject_list.txt)

for name in ${subject_list}; do

	bblid=$(basename ${name} | cut -d_ -f1)
	scanid=$(basename ${name} | cut -d_ -f2)
	dateid=$(basename ${name} | cut -d_ -f3)

	echo $bblid
	echo $scanid
	echo $dateid

	subj="${bblid}"/"${dateid}"x"${scanid}"

	#####################################
	### Define input and output paths ###
	#####################################

	## Local path to git repo
	repo_dir=/home/gbaum/pncDwiTractNet

	## Deterministic output directory
	det_outdir=/data/joy/BBL/studies/pnc/processedData/diffusion/deterministic_20171118/"${subj}"

	## Deterministic log directory
	det_log_dir=${det_outdir}/logfiles
	mkdir -p ${det_log_dir}

	## Bedpostx directory containing "merged_f1samples.nii.gz" and other output
	bedpostx_dir=/data/joy/BBL/studies/pnc/processedData/diffusion/pncDTI_2016_04/"${subj}"/bedpostx_64_output

	## Probtrackx output directory for
	ptx_outdir=/data/joy/BBL/studies/pnc/processedData/diffusion/probabilistic_20171118/"${subj}"
	
	## Create new directory structure
	mkdir -p "${ptx_outdir}"/input

	## Subject log directory
	prob_log_dir="${ptx_outdir}"/logfiles
	mkdir -p ${prob_log_dir}

	########################################################################
	## Write probabilistic script into a subject-specific script for qsub ##
	########################################################################
 	var1="pushd ${repo_dir}; ./run_probabilistic_tractography.sh ${bblid} ${dateid} ${scanid}; popd"

	prob_tract_script=${prob_log_dir}/run_probTract_schaefer200_wmEdge_p1000_"${bblid}"_"${dateid}"x"${scanid}".sh
	rm ${prob_log_dir}/run_probTract_schaefer200_wmEdge_p1000_"${bblid}"_"${dateid}"x"${scanid}".*
	# echo -e "${var1}"
	echo -e "${var1}" > ${prob_tract_script}

	########################################################################
	## Write deterministic script into a subject-specific script for qsub ##
	########################################################################
	var0="pushd ${repo_dir}; ./run_deterministic_tractography.sh ${bblid} ${dateid} ${scanid}; export bblid; export dateid; export scanid; qsub -q all.q,basic.q -wd ${prob_log_dir} -l h_vmem=5G,s_vmem=4G ${prob_tract_script}; popd"
	
	det_tract_script=${det_log_dir}/run_detTract_schaefer200_"${bblid}"_"${dateid}"x"${scanid}".sh
	rm ${det_log_dir}/run_detTract_schaefer200_"${bblid}"_"${dateid}"x"${scanid}".*
	# echo -e "${var0}"
	echo -e "${var0}" > ${det_tract_script}
 	
	## Execute qsub job for deterministic tractography 
	qsub -q all.q,basic.q -wd ${det_log_dir} -l h_vmem=4G,s_vmem=3G ${det_tract_script}
done
