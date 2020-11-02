function ML_generate_PT_Amat(ptx_dir, conmat_outpath, roiVol_path, bblid, dateid, scanid)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Load vector of regional volumes %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
roiVol_path
C=load(roiVol_path);

% Remove brain stem due to poor coverage
% C(234)=[];
numNodes=numel(C);
volMat=zeros(numNodes);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Create ROI volume matrix where element Aij = sum of ROI(i) volume + ROI(j) volume %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for j=1:numNodes

	for k=1:numNodes
		volMat(j,k)= C(j) + C(k);
	end
end

%% Navigate to output directory
cd(ptx_dir)
cd('output')

X = numNodes; % Define number of ROIs
A_prop = []; % Create empty matrix for connectivity probability 
A_raw_sc = []; % Create empty matrix for streamline count 
A_raw_length = []; % Create empty matrix for mean streamline length 
P = 1000  % Number of streamlines propagated per seed voxel

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Build the connectivity matrix from each ROIseed output directory %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for R=1:X
	%% Open the output directory for ROI `R`
	name=sprintf('ROIseed_%d_output',R);
	cd(name)

	%% Waytotal is used for calculating connectivity probability. 
	%% Waytotal is equal to the number of streamlines that were initiated 
	%% in the seed region and terminated in the target region (given the waypoint and exclusion criteria)
	load waytotal;

	%% Load streamline count matrix (dimensions: number of seed voxels by number of target regions)
	load matrix_seeds_to_all_targets;
	
	%% Load mean streamline length matrix (number of seed voxels X number of target regions)
	load matrix_seeds_to_all_targets_lengths;

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%	
	% Sum across columns of 'matrix_seeds_to_all_targets' in order to 
	% calculate the seed region's connectivity to all other regions
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%	
	
	%%%%%%%%%%%%%%%%%%%%
	% Streamline count %
	%%%%%%%%%%%%%%%%%%%%
	vector_sc=sum(matrix_seeds_to_all_targets,1);
	A_raw_sc=[A_raw_sc;vector_sc];

	%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% Connectivity probability %
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	vector_prop=vector_sc./waytotal;
	A_prop=[A_prop;vector_prop];

	%%%%%%%%%%%%%%%%%%%%%%%%%%
	% Mean streamline length %
	%%%%%%%%%%%%%%%%%%%%%%%%%%
	length_vec=dot(matrix_seeds_to_all_targets,matrix_seeds_to_all_targets_lengths);
	length_vec= length_vec ./ sum(matrix_seeds_to_all_targets,1);
	isnan_idx=find(isnan(length_vec));
	length_vec(:,isnan_idx)=0;	
	A_raw_length=[A_raw_length;length_vec];


	cd ../

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Make matrices undirected by averaging matrix elements in upper and lower triangles %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for x=1:X
	for y=1:X
    			A_sc_und(x,y)=(A_raw_sc(x,y) + A_raw_sc(y,x))/2 ;
   			A_prop_und(x,y)=(A_prop(x,y)+A_prop(y,x))/2 ;
   		A_length_und(x,y)=(A_raw_length(x,y) + A_raw_length(y,x))/2 ;
	end
end

%% Set matrix diagonal to zero
A_sc_und=(A_sc_und - diag(diag(A_sc_und)));
A_prop_und=(A_prop_und - diag(diag(A_prop_und)));
A_length_und=(A_length_und - diag(diag(A_length_und)));

%% Create volume-normalized streamline density matrix
A_volNorm_sc_und = A_sc_und./volMat;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% A_raw_sc = Directed, raw connectivity matrix, not normalized by waytotal         
% A_prop = Directed, connectivity matrix where edges are normalized by Waytotal of seed ROI
% A_sc_und = Undirected, raw connectivity matrix, not normalized by Waytotal
% A_prop_und = Undirected,connectivity matrix where edges are normalized by Waytotal of seed ROI
% A_volNorm_sc_und = Undirected raw connectivity matrix normalized by volume of seed and target ROIs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Redefine dumb matrix names
streamlineCount_mat = A_sc_und;
connProbability_mat = A_prop_und;
streamlineLength_mat = A_length_und;
volNormSC_mat = A_volNorm_sc_und;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Save connectivity matrix output for each subject %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
savename = conmat_outpath
save(savename,'streamlineCount_mat', 'connProbability_mat', 'streamlineLength_mat','streamlineLength_mat', 'volMat')
