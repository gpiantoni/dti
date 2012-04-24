function dti_rand(cfg)
%DTI_RAND run randomise on the folder
%
% CFG
%  .dtifa.tbss: directory name for all FA etc files
%  .dtifa.type: type of images to analyze (a cell, as {'FA' 'L1' 'RD'})
%
%  .dtirand: string with options to pass to randomise:
%    ' -D ': to demean the DTI values (suggested, especially if you're not
%    using the intercept in design matrix)
%    ' -n XXXX ': number of randomizations
%    ' --T2 ': TFCE correction (best options). All options are
%  FWE:
%    -x   -> single voxel correction: _vox_p_tstat  | _vox_corrp_tstat
%    --T2 -> TFCE correction:         _tfce_p_tstat | _tfce_corrp_tstat
%    -c N -> cluster-size correction:               | _clustere_corrp_tstat
%    -C N -> cluster-mass correction:               | _clusterm_corrp_tstat
%
% INPUT
%  cfg.dtifa.tbss directory, with subfolder:
%   1) 'design', with files .con and .mat, the design matrix (from DTI_DESIGN)
%   2) 'stats', created by FSL (from DTI_TBSS)
%
% OUTPUT
%  cfg.dtifa.tbss has stats analyzed
%
% Part of DTI
% see also DTI_CONVERT, DTI_PREPROC, DTI_FA, DTI_BEDPOSTX, DTI_PROBTRACKX
%          DTI_TBSS, DTI_DESIGN, DTI_RAND, ATLAS_MASK

%---------------------------%
%-start log
output = sprintf('%s started at %s on %s\n', ...
  mfilename, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'));
tic_t = tic;
%---------------------------%

%---------------------------%
%-directory with design and for randomisation
desd = [cfg.dtifa.tbss 'design/'];
randd = [cfg.dtifa.tbss 'rand/'];
if isdir(randd); rmdir(randd, 's'); end
mkdir(randd)
%---------------------------%

%-------------------------------------%
%-loop over designs
%---------------------------%
%-check which designs are available in design/ folder (don't rely on
%DTI_DESIGN, some of them might not be available)
des = dir([desd '*.con']);
%---------------------------%

nimg = 0;
for d = 1:numel(des)
  
  %---------------------------%
  %-dir and files
  desname = des(d).name(1:end-4);
  desmat = [desd desname '.mat'];
  descon = [desd desname '.con'];
  %---------------------------%
  
  %---------------------------%
  %-count number of contrasts in one design
  fid = fopen(descon, 'r');
  ncon = 0;
  while 1
    
    l = fgetl(fid);
    if numel(l) < 13 || ~strcmp(l(1:13), '/ContrastName')
      break
    end
    ncon = ncon + 1;
  end
  fclose(fid);
  %---------------------------%
  
  %---------------------------%
  %-----------------%
  %-compute model
  cdir = pwd;
  cd(cfg.dtifa.tbss)
  
  %-------%
  %-parameter for randomise
  opt = [];
  opt.d = desmat;
  opt.t = descon;
  opt.m = [cfg.dtifa.tbss 'stats/mean_FA_skeleton_mask.nii.gz'];
  %-------%
  
  for i = 1:numel(cfg.dtifa.type)
    if ~strcmp(cfg.dtifa.type{i}(1), 'V') % it cannot handle 3d data
      
      nimg = nimg + ncon; % corrp_tstat1, corrp_tstat2, corrp_tstat3 etc
      
      opt.i = [cfg.dtifa.tbss 'stats/all_' cfg.dtifa.type{i} '.nii.gz'];
      opt.o = [randd desname '_' cfg.dtifa.type{i}];
      system(['randomise_parallel -i ' opt.i ' -o "' opt.o '" -d "' opt.d '" -t "' opt.t '" -m ' opt.m ' ' cfg.dtirand]);
      
    end
  end
  
  cd(cdir)
  %-----------------%
  %---------------------------%
  
end

%-----------------%
%-check whether the program has finished
[~, username] = system('whoami');
username(end) = [];
while 1
  pause(15)
  
  %-method 1: check if randomise running
  %it fails bc it takes some time to initialize
  [~, running] = system(['ps -u ' username ' | grep -c randomise']);
  fprintf([datestr(now, 'HH:MM:SS') '  ' running])
  
  %-method 2:
  allwr = dir([randd '*_corrp_tstat*.nii.gz']);
  allseed = numel(find(~cellfun(@isempty, strfind({allwr.name}, 'SEED'))));

  if numel(allwr) - allseed == nimg
    break
  end
  
  pause(45)
end
disp('done')
%-----------------%
%-------------------------------------%

%---------------------------%
%-end log
toc_t = toc(tic_t);
outtmp = sprintf('%s ended at %s on %s after %s\n\n', ...
  mfilename, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'), ...
  datestr( datenum(0, 0, 0, 0, 0, toc_t), 'HH:MM:SS'));
output = [output outtmp];

%-----------------%
fprintf(output)
fid = fopen([cfg.log '.txt'], 'a');
fwrite(fid, output);
fclose(fid);
%-----------------%
%---------------------------%
