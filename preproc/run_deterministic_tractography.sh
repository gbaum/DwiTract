#!/bin/sh

# Source Graham's bash profile
source /home/gbaum/.bash_profile

##################################
### Define subject identifiers ###
##################################
bblid=$1
dateid=$2
scanid=$3 

echo $bblid
echo $dateid
echo $scanid

subj="${bblid}"/"${dateid}"x"${scanid}"

## FreeSurfer subject directory
SUBJECTS_DIR=/data/joy/BBL/studies/pnc/processedData/structural/freesurfer53

## DSI Studio executable path
dsiBin="/share/apps/dsistudio/2016-01-25/bin/dsi_studio"

##############################################################
### Define directory structure and inputs for each subject ###
##############################################################
echo $bblid
echo $scanid
echo $dateid

subj=${bblid}/"${dateid}"x"${scanid}"

roalfDir=/data/joy/BBL/studies/pnc/processedData/diffusion/pncDTI_2016_04/${bblid}/"${dateid}"x"${scanid}"/DTI_64
	
det_outdir=/data/joy/BBL/studies/pnc/processedData/diffusion/deterministic_20171118/"${subj}"

det_log_dir=${det_outdir}/logfiles

inputDir=${det_outdir}/input

dsi_det_outdir=${det_outdir}/dsiStudioRecon
	
baumDir=/data/joy/BBL/studies/pnc/processedData/diffusion/deterministic_20161201/"${bblid}"/"${dateid}"x"${scanid}"

mkdir -p ${dsi_det_outdir}

#################################################################################
## Assign DTI image variables - Use eddy, motion, and distortion-corrected DWI ##
#################################################################################
dico_path=${roalfDir}/dico_corrected/"${bblid}"_"${dateid}"x"${scanid}"_dico_dico.nii.gz
mask_path=${roalfDir}/raw_merged_dti/"${bblid}"_"${dateid}"x"${scanid}"_dtistd_2_mask.nii.gz

# Sym-link eddy and distortion-corrected DTI file
ln -s ${dico_path} ${inputDir}/
	
# Sym-link mask
ln -s ${mask_path} ${inputDir}/

# DTI Reference volume
ln -s /data/joy/BBL/studies/pnc/processedData/diffusion/dti2xcp_201606230942/${subj}/dti2xcp/"${bblid}"_"${dateid}"x"${scanid}"_referenceVolume.nii.gz "${inputDir}"/"${bblid}"_"${dateid}"x"${scanid}"_referenceVolume.nii.gz

###########################
## DTI Brain Extraction ##
##########################

## Use Roalf's registration-based FMRIB58 mask to remove skull from DWI
# fslmaths ${dico_path} -mas ${mask_path} "${det_outdir}"/input/"${bblid}"_"${dateid}"x"${scanid}"_dico_dico_masked.nii.gz

masked_dico_path="${det_outdir}"/input/"${bblid}"_"${dateid}"x"${scanid}"_dico_dico_masked.nii.gz

################################################################
## Define subject-specific Rotated bvecs and other DTI inputs ##
################################################################
bvecs=${roalfDir}/raw_merged_dti/"${bblid}"_"${dateid}"x"${scanid}"_dti_merged_rotated.bvec
echo " "
echo "Subject-specific rotated bvecs file"
echo " "
echo ${bvecs}

ln -s ${bvecs} ${inputDir}/

## Bvals and acqparams 	are identical for all subjects ##
bvals=${roalfDir}/raw_merged_dti/"${bblid}"_"${dateid}"x"${scanid}"_dti_merged.bval 
echo " "
echo "bval file"
echo " "
echo ${bvals}
	
ln -s ${bvals} ${inputDir}/

indexfile=/data/joy/BBL/projects/pncReproc2015/diffusionResourceFiles/index_64.txt
acqparams=/data/joy/BBL/projects/pncReproc2015/diffusionResourceFiles/acqparams.txt 
	
##############################################
### Convert DWI input to DSI Studio format ###
##############################################
${dsiBin} --action=src --source="${masked_dico_path}" --bval="${bvals}" --bvec="${bvecs}" --output="${dsi_det_outdir}"/${bblid}_"${dateid}"x"${scanid}"_dico_dico_masked.src.gz

# Define DSI Studio source file for reconstruction and tractography
dti_source="${dsi_det_outdir}"/${bblid}_"${dateid}"x"${scanid}"_dico_dico_masked.src.gz

## DTI reconstruction
${dsiBin} --action=rec --source=${dti_source} --mask=${mask_path} --method=1 
	
## Define reconstruction file (fib)
dti_reconstruction=$(ls ${dsi_det_outdir}/"${bblid}"_"${dateid}"x"${scanid}"_*dti*fib.gz )

## Export the FA maps from fib file
${dsiBin} --action=exp --source=${dti_reconstruction} --export=fa0

####################################
## Run Deterministic Tractography ##
####################################

## Tractography output directory
tract_dir="${det_outdir}"/tractography
mkdir -p ${tract_dir}/connectivity
	
# DTI(FA-guided) tractography
# ${dsiBin} --action=trk --source="${dti_reconstruction}" --method=0 --fiber_count=1000000 --turning_angle=45 --min_length=10 --max_length=400 --output=${tract_dir}/${bblid}_"${dateid}"x"${scanid}"_dti_tractography.trk.gz --export="stat"

dti_tractography=${tract_dir}/${bblid}_"${dateid}"x"${scanid}"_dti_tractography.trk.gz

echo "DTI (FA-guided) Tractography output"
echo ""
echo ${dti_tractography}
echo ""

###############################################
## Create Schaefer Parcellation in DTI space ##
###############################################

## Define inputs to ANTs call
PNC_template=/home/rciric/xcpAccelerator/xcpEngine/space/PNC/PNC-9375x9375x1.nii.gz
schaeferPNC_template=/data/joy/BBL/applications/xcpEngine/networks/SchaeferPNC.nii.gz
dti_refVol=/data/joy/BBL/studies/pnc/processedData/diffusion/dti2xcp_201606230942/${bblid}/"${dateid}"x"${scanid}"/dti2xcp/${bblid}_"${dateid}"x"${scanid}"_referenceVolume.nii.gz
struct2seq_coreg=/data/joy/BBL/studies/pnc/processedData/diffusion/dti2xcp_201606230942/${bblid}/"${dateid}"x"${scanid}"/coreg/${bblid}_"${dateid}"x"${scanid}"_struct2seq.txt
antsDir=/data/joy/BBL/studies/pnc/processedData/structural/antsCorticalThickness/${bblid}/"${dateid}"x"${scanid}"
pncTemplate2subjAffine=${antsDir}/TemplateToSubject1GenericAffine.mat
pncTemplate2subjWarp=${antsDir}/TemplateToSubject0Warp.nii.gz
pncTransformDir=/home/rciric/xcpAccelerator/xcpEngine/space/PNC/PNC_transforms

######################################
## LOOP THROUGH EACH SCHAEFER SCALE ##
######################################

for i in 200; do # 100 400 600 800 1000

	rm -rf "${det_outdir}"/input/roi/Schaefer"${i}"/
	mkdir -p "${det_outdir}"/input/roi/Schaefer"${i}"

	## Parcellation in dti space (output)
	schaeferDti_path="${det_outdir}"/input/roi/Schaefer"${i}"/${bblid}_"${dateid}"x"${scanid}"_SchaeferPNC_"${i}"_dti.nii.gz

	## Move MNI templates to PNC
	schaeferDir=/data/joy/BBL/projects/pncBaumDti/Schaefer2018_LocalGlobal_Parcellation/CBIG-master/stable_projects/brain_parcellation/Schaefer2018_LocalGlobal/Parcellations/MNI
	schaefer_mni=${schaeferDir}/Schaefer2018_"${i}"Parcels_17Networks_order_FSLMNI152_1mm.nii.gz
	dilated_schaefer_mni=${schaeferDir}/Schaefer2018_"${i}"Parcels_17Networks_order_FSLMNI152_1mm_dil1.nii.gz
	schaefer_pnc=/data/joy/BBL/applications/xcpEngine/networks/SchaeferPNC_"${i}"_dil1.nii.gz

	## Dilate Schaefer parcellation in MNI space before moving to PNC template space
	ImageMath 3 ${dilated_schaefer_mni} GD ${schaefer_mni} 1 

	## Move Schaefer parcellation from MNI space to PNC template
	antsApplyTransforms -e 3 -d 3 -i ${dilated_schaefer_mni} -r ${PNC_template} -o ${schaefer_pnc} -t ${pncTransformDir}/MNI-PNC_1Warp.nii.gz -t ${pncTransformDir}/MNI-PNC_0Affine.mat -n Multilabel

	## Move Schaefer parcellation from PNC template to subject DTI space ##	
	antsApplyTransforms -e 3 -d 3 -i ${schaefer_pnc} -r ${dti_refVol} -o ${schaeferDti_path} -t ${struct2seq_coreg} -t ${pncTemplate2subjAffine} -t ${pncTemplate2subjWarp} -n MultiLabel

	##################################################
	## Get volume of each ROI for each parcellation ##
	##################################################
	schaefer_vol_output="${det_outdir}"/input/roi/Schaefer"${i}"/SchaeferPNC_"${i}"_dti_roiVol.txt
	rm ${schaefer_vol_output}

	for reg in $(seq 1 ${i}); do	
		# echo ${reg}
		3dBrickStat -non-zero -count "${schaeferDti_path}<${reg}>" 2>>/dev/null 1>> ${schaefer_vol_output}
	done
	
	###################################################################
	## DSI Studio command to generate Schaefer connectivity matrices ##
	###################################################################

	## Remove old connectivity matrices
	rm ${tract_dir}/connectivity/${bblid}_"${dateid}"x"${scanid}"_SchaeferPNC_"${i}"_*.mat

	## Generate DTI-based (FA) matrices
	"${dsiBin}" --action=ana --source="${dti_reconstruction}" --tract="${dti_tractography}" --connectivity="${schaeferDti_path}" --connectivity_value=fa,adc,count,mean_length --connectivity_type=end

	## Rename and move matrices to proper output directory
	Schaefer_fa_mat=$(ls ${dsi_det_outdir}/*SchaeferPNC*fa*.mat)
	Schaefer_adc_mat=$(ls ${dsi_det_outdir}/*SchaeferPNC*adc*.mat)
	Schaefer_count_mat=$(ls ${dsi_det_outdir}/*SchaeferPNC*count*.mat)
	Schaefer_length_mat=$(ls ${dsi_det_outdir}/*SchaeferPNC*length*.mat)

	mv ${Schaefer_fa_mat} ${tract_dir}/connectivity/${bblid}_"${dateid}"x"${scanid}"_SchaeferPNC_"${i}"_dti_fa_connectivity.mat
	mv ${Schaefer_adc_mat} ${tract_dir}/connectivity/${bblid}_"${dateid}"x"${scanid}"_SchaeferPNC_"${i}"_dti_adc_connectivity.mat
	mv ${Schaefer_count_mat} ${tract_dir}/connectivity/${bblid}_"${dateid}"x"${scanid}"_SchaeferPNC_"${i}"_dti_streamlineCount_connectivity.mat
	mv ${Schaefer_length_mat} ${tract_dir}/connectivity/${bblid}_"${dateid}"x"${scanid}"_SchaeferPNC_"${i}"_dti_mean_streamlineLength_connectivity.mat
done
