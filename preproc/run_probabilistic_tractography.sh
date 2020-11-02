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

## Freesurfer subjects directory
SUBJECTS_DIR=/data/joy/BBL/studies/pnc/processedData/structural/freesurfer53

## Local path to git repo
repo_dir=/home/gbaum/pncDwiTractNet

####################################################################
### Define input and output paths for probabilistic tractography ###
####################################################################

## Bedpostx directory containing "merged_f1samples.nii.gz" and other output
bedpostx_dir=/data/joy/BBL/studies/pnc/processedData/diffusion/pncDTI_2016_04/"${subj}"/bedpostx_64_output

## COPY BEDPOSTX OUTPUT TO TMPDIR
mkdir -p ${TMPDIR}/${subj}
cp -r ${bedpostx_dir}/ ${TMPDIR}/${subj}

tmp_bedpostx_dir=${TMPDIR}/${subj}/bedpostx_64_output

## Probtrackx output directory
ptx_outdir=/data/joy/BBL/studies/pnc/processedData/diffusion/probabilistic_20171118/"${subj}"

## Subject log directory
log_dir="${ptx_outdir}"/logfiles
mkdir ${log_dir}

## Sym-link to dti2xcp transform files
ln -s /data/joy/BBL/studies/pnc/processedData/diffusion/dti2xcp_201606230942/${subj}/dti2xcp/"${bblid}"_"${dateid}"x"${scanid}"_referenceVolume.nii.gz "${ptx_outdir}"/input/"${bblid}"_"${dateid}"x"${scanid}"_referenceVolume.nii.gz
ln -s /data/joy/BBL/studies/pnc/processedData/diffusion/dti2xcp_201606230942/${subj}/coreg/"${bblid}"_"${dateid}"x"${scanid}"_struct2seq.txt "${ptx_outdir}"/input/"${bblid}"_"${dateid}"x"${scanid}"_struct2seq.txt
	
#######################################
## Define WM Segmentation for wmEdge ##
#######################################
	
## antsCT WM segmentation in T1 space
fslmaths /data/joy/BBL/studies/pnc/processedData/structural/antsCorticalThickness/${subj}/BrainSegmentation.nii.gz -thr 3 -uthr 3 "${ptx_outdir}"/input/${bblid}_"${dateid}"x"${scanid}"_antsCT_WMseg03.nii.gz

## Move into subject diffusion space
WMseg_t1="${ptx_outdir}"/input/${bblid}_"${dateid}"x"${scanid}"_antsCT_WMseg03.nii.gz
WMseg_dti="${ptx_outdir}"/input/${bblid}_"${dateid}"x"${scanid}"_antsCT_WMseg03_dti.nii.gz
	
antsApplyTransforms -d 3 -e 0 -i "${WMseg_t1}" -r /data/joy/BBL/studies/pnc/processedData/diffusion/dti2xcp_201606230942/${subj}/dti2xcp/"${bblid}"_"${dateid}"x"${scanid}"_referenceVolume.nii.gz -t /data/joy/BBL/studies/pnc/processedData/diffusion/dti2xcp_201606230942/${subj}/coreg/"${bblid}"_"${dateid}"x"${scanid}"_struct2seq.txt -o "${WMseg_dti}" -n MultiLabel

waypoint_mask=${WMseg_dti}
echo ""
echo "Probtrackx2 WM Waypoint Mask"
echo ${waypoint_mask}
echo ""

# ###################################
# ### Define CSF "Avoidance Mask" ###
# ###################################
fslmaths /data/joy/BBL/studies/pnc/processedData/structural/antsCorticalThickness/${subj}/BrainSegmentation.nii.gz -thr 1 -uthr 1 "${ptx_outdir}"/input/${bblid}_"${dateid}"x"${scanid}"_antsCT_CSFseg01.nii.gz
	
# Move into subject diffusion space
csf_t1="${ptx_outdir}"/input/${bblid}_"${dateid}"x"${scanid}"_antsCT_CSFseg01.nii.gz
csf_dti="${ptx_outdir}"/input/${bblid}_"${dateid}"x"${scanid}"_antsCT_CSFseg01_dti.nii.gz
	
antsApplyTransforms -d 3 -e 0 -i "${csf_t1}" -r /data/joy/BBL/studies/pnc/processedData/diffusion/dti2xcp_201606230942/${subj}/dti2xcp/"${bblid}"_"${dateid}"x"${scanid}"_referenceVolume.nii.gz -t /data/joy/BBL/studies/pnc/processedData/diffusion/dti2xcp_201606230942/${subj}/coreg/"${bblid}"_"${dateid}"x"${scanid}"_struct2seq.txt -o "${csf_dti}" -n MultiLabel
avoid_mask="${csf_dti}"

echo ""
echo "Probtrackx2 CSF Avoidance Mask"
echo ${avoid_mask}
echo ""

# ###################################################
# ### Create white matter edge in diffusion space ###
# ###################################################
WMseg_edge="${ptx_outdir}"/input/${bblid}_"${dateid}"x"${scanid}"_antsWMseg_edge_dti.nii.gz
dil_WMseg_edge="${ptx_outdir}"/input/${bblid}_"${dateid}"x"${scanid}"_antsWMseg_edge_dti_dil1.nii.gz

fslmaths ${WMseg_dti} -edge ${WMseg_edge}

# ## Dilate WM edge by 1 voxel 
ImageMath 3 ${dil_WMseg_edge} GD ${WMseg_edge} 1

######################################
## LOOP THROUGH EACH SCHAEFER SCALE ##
######################################

for i in 200; do # 100 400 600 800 1000

	roi_dir="${ptx_outdir}"/input/roi/Schaefer"${i}"
	rm -rf ${roi_dir}/
	mkdir -p "${roi_dir}"

	# Number of regions
	nreg=${i}

	# schaefer_outdir="${ptx_outdir}"/output/Schaefer"${i}"
	# mkdir -p "${schaefer_outdir}"
	
	##############################################################################
	## Sym-links for Schaefer parcellation generated for Deterministic pipeline ##
	##############################################################################
	det_outdir=/data/joy/BBL/studies/pnc/processedData/diffusion/deterministic_20171118/"${subj}"

	schaeferDti_path=${det_outdir}/input/roi/Schaefer"${i}"/${bblid}_"${dateid}"x"${scanid}"_SchaeferPNC_"${i}"_dti.nii.gz

	# Sym-link Schaefer parcellations
	ln -s ${schaeferDti_path} "${roi_dir}"/

	# Sym-link DTI input from deterministic pipeline
	ln -s ${det_outdir}/input/* "${ptx_outdir}"/input/

	#######################################################
	## Mask GM atlas by WM Boundary (in diffusion space) ##
	#######################################################
	wmMasked_dti_atlas="${roi_dir}"/${bblid}_"${dateid}"x"${scanid}"_SchaeferPNC_"${i}"_dti_wmEdgeMasked.nii.gz

	fslmaths "${schaeferDti_path}" -mas "${dil_WMseg_edge}" "${wmMasked_dti_atlas}" 

	##################################################
	## Get volume of each ROI for each parcellation ##
	##################################################
	schaefer_vol_output="${roi_dir}"/SchaeferPNC_"${i}"_dti_wmEdgeMasked_roiVol.txt

	for reg in $(seq 1 ${i}); do 
		# echo ${reg}
		3dBrickStat -non-zero -count "${wmMasked_dti_atlas}<${reg}>" 2>>/dev/null 1>> ${schaefer_vol_output}
	done
		
	#######################################################
	### Create Individual Seed/Target ROIs for tracking ###
	#######################################################
	seed_dir="${roi_dir}"/seedVols
	mkdir -p "${seed_dir}"

	pushd "${roi_dir}"/

	 	matlab -nodisplay -nodesktop -r "input_dir=dir('*dti_wmEdgeMasked.nii.gz'); nii=load_nifti(input_dir.name); vol_orig = nii.vol; nreg=max(unique(vol_orig)); for r = 1:nreg; vol_roi = vol_orig; vol_roi(vol_roi ~= r) = 0; nii.vol = vol_roi; save_nifti(nii, strcat('ROIseed_', int2str(r), '.nii.gz')); end; exit"

	 	mv "${roi_dir}"/ROIseed_*.nii.gz "${seed_dir}"
	popd
		
	####################################################
	### Create Seed-Target text file for Probtrackx2 ###
	####################################################
	seedTarget_file="${ptx_outdir}"/input/"${bblid}"_"${dateid}"x"${scanid}"_SchaeferPNC"${i}"_17network_wmEdge_ptx_seedTargets.txt
	rm ${seedTarget_file}

	for s in $(seq 1 ${nreg}); do
		  echo "${s}"
		  echo "${seed_dir}"/ROIseed_"${s}".nii.gz >> ${seedTarget_file}
	done

	######################################################################
	### Create Termination Mask by Subtracting GM ROIs and from wmEdge ###
	######################################################################
	termination_mask="${ptx_outdir}"/input/"${bblid}"_"${dateid}"x"${scanid}"_schaefer"${i}"_GM_termination_mask.nii.gz

	fslmaths ${schaeferDti_path} -sub ${wmMasked_dti_atlas} "${termination_mask}"

	#############################################
	### Define variables for probtrackx2 call ###
	#############################################
	ptx_bin="/share/apps/fsl/5.0.9/bin/probtrackx2"

	echo ""
	echo "Probtrackx Version"
	echo ${ptx_bin}
	echo ""

	## Number of streamlines propogated for each seed voxel
	ncount=1000
	echo ""
	echo "Number of streamlines initiated in each seed voxel: ${ncount}"
	echo ""

	## Diffusion reference volume
	dti_refVol="${ptx_outdir}"/input/"${bblid}"_"${dateid}"x"${scanid}"_referenceVolume.nii.gz
		
	seed_paths=$(cat "${seedTarget_file}")

	#######################################################################	
	### Run probtrackx2 and setup output structure for each seed region ###
	#######################################################################

	for seed in ${seed_paths};do
		seedName=$(basename ${seed} .nii.gz)
		echo ${seedName}

		## Define probtrackx output directory 
		curr_outdir=${ptx_outdir}/output/schaefer"${i}"/${seedName}_output
			
		mkdir -p ${curr_outdir}
		mkdir -p ${TMPDIR}/${subj}/${seedName}_output

		## Probtrackx2 call
		${ptx_bin} -s ${tmp_bedpostx_dir}/merged -m ${tmp_bedpostx_dir}/nodif_brain_mask.nii.gz -x ${seed} --seedref=${dti_refVol} --avoid=${avoid_mask} --waypoints=${waypoint_mask} --stop=${termination_mask} --ompl --os2t --s2tastext --opd -l -c 0.2 -S 2000 --steplength=0.5 -P ${ncount} -V 1 --forcedir --dir=${TMPDIR}/${subj}/${seedName}_output --targetmasks=${seedTarget_file}

		## Matrix output seed-to-targets (text files) in $TMPDIR
		cp ${TMPDIR}/${subj}/${seedName}_output/matrix_seeds_to_all_targets ${curr_outdir}/
		cp ${TMPDIR}/${subj}/${seedName}_output/matrix_seeds_to_all_targets_lengths ${curr_outdir}/

		## Waytotal
		cp ${TMPDIR}/${subj}/${seedName}_output/waytotal ${curr_outdir}/

		## Path distributions
		cp ${TMPDIR}/${subj}/${seedName}_output/fdt_paths* ${curr_outdir}/

		## Probtrackx log file
		cp ${TMPDIR}/${subj}/${seedName}_output/probtrackx.log ${curr_outdir}/

	done

	####################################################
	### Generate Probabilistic Connectivity Matrices ###
	####################################################
	final_outdir=${ptx_outdir}/output/schaefer"${i}"/connectivity
	mkdir -p "${final_outdir}"

	conmat_outpath="${final_outdir}"/${bblid}_"${dateid}"x"${scanid}"_ptx_p1000_wmEdge_Schaefer"${i}"_17net.mat

	roiVol_path="${schaefer_vol_output}"

	pushd "${repo_dir}"

	matlab -nosplash -nodesktop -logfile ${log_dir}/gen_ptx_conmat_Schaefer"${i}".log -r "generate_ptx_conmat ${ptx_outdir} ${conmat_outpath} ${roiVol_path} ${bblid} ${dateid} ${scanid}; exit()"

	popd

done 
