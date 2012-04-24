function dti_bedpostx(cfg, subj)
%DTI_BEDPOSTX run bedpostx on dti directory
%
% CFG
%  .rec: name of the recording
%  .data: name of projects/PROJNAME/subjects/
%  .dti.mod: 'smri' (modality of DTI)
%  .dti.cond: 'dti' (condition of DTI)
%
%  .dti.b0: index of the volume with no gradient applied (use FSL convetion starting at 0)
%  .dti.bvec: used to specify the last part of the name of the gradient (bvec)
%  .dti.dtiprep: used to specify the last part of the name of the DWI file
%  (if you did eddy current, it's '_ec'. It can be '').
%
%  .dti.ref: template for flirt realignment ('/usr/share/data/fsl-mni152-templates/MNI152_T1_1mm_brain.nii.gz')
%            if empty, no registration
% INPUT
%  Should be in CFG.DATA/0001/CFG.DTI.MOD/CFG.DTI.COND/ and contain:
%  - PROJNAME_SUBJ_smri_dti(CFG.DTIPREP).nii.gz: DWI images, eventually after preprocessing
%  - PROJNAME_SUBJ_smri_dti.bval: b-values (vector 0 and 1000 usually)
%  - PROJNAME_SUBJ_smri_dti(CFG.BVEC): b-vectors, you should specify the last part of the name with cfg.bvec (can be '.grad', '.bvec', '_orig.grad' etc)
%  - PROJNAME_SUBJ_smri_dti_ng_mask.nii.gz: mask for DWI
%
% OUTPUT
%  - complete bedpostx folder
%  - affine for linear registration to cfg.dti.ref
%
% Part of DTI
% see also DTI_CONVERT, DTI_PREPROC, DTI_FA, DTI_BEDPOSTX, DTI_PROBTRACKX
%          DTI_TBSS, DTI_DESIGN, DTI_RAND, ATLAS_MASK

%---------------------------%
%-start log
output = sprintf('(p%02.f) %s started at %s on %s\n', ...
  subj, mfilename, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'));
tic_t = tic;
%---------------------------%

%---------------------------%
%-dir and files
ddir = sprintf('%s%04.f/%s/%s/', cfg.data, subj, cfg.dti.mod, cfg.dti.cond); % data directory
beddir = [ddir 'bed/']; % starting directory
bedpostxdir = [beddir(1:end-1) '.bedpostX/'];

if isdir(beddir); rmdir(beddir, 's'); end
mkdir(beddir)
if isdir(bedpostxdir); rmdir(bedpostxdir, 's'); end

file = sprintf('%s_%04.f_%s_%s', cfg.rec, subj, cfg.dti.mod, cfg.dti.cond);

dfile  = [file cfg.dti.dtiprep];
ngfile = [file '_ng'];
bvec   = [file cfg.dti.bvec];
bval   = [file '.bval'];
%---------------------------%

%---------------------------%
%-move good files to bedpostx directory
bash(['ln ' ddir dfile '.nii.gz ' beddir 'data.nii.gz']);
bash(['ln ' ddir file '_ng_mask.nii.gz ' beddir 'nodif_brain_mask.nii.gz']);
bash(['ln ' ddir bvec ' ' beddir 'bvecs']);
bash(['ln ' ddir bval ' ' beddir 'bvals']);
%---------------------------%

%---------------------------%
%-bedpostx
bash(['bedpostx ' beddir]);

%-----------------%
%-check whether the program has finished
[~, nslices] = bash(['cat ' bedpostxdir 'commands.txt | wc -l']);
nslices = eval(nslices);

while 1
  pause(15)
  
  %-------%
  %-number of slices which are done
  [~, done] = bash(['ls ' bedpostxdir 'diff_slices/data_slice_00*/dyads1.nii.gz -l | wc -l']);
  if numel(done) > 100 % something like: 'ls: cannot access etc'
    done = 0;
  else
    done = eval(done);
  end
  %-------%
  
  %-------%
  %-check if it's running
  [run_ss] = bash('ps -u gpiantoni | grep -c xfibres');
  run_ss = eval(run_ss);
  [run_nin111] = bash('ssh nin111 ps -u gpiantoni | grep -c xfibres');
  run_nin111 = eval(run_nin111);
  
  fprintf('%s % 3d/% 3d (running% 3d on somerenserver,% 3d on nin111)\n', datestr(now, 'HH:MM:SS'), done, nslices, run_ss, run_nin111);
  %-------%
  
  %-------%
  %-check if finished
  allwr = dir([bedpostxdir 'mean_S0samples.nii.gz']); % <- modify num2str if you move this outside the d-loop

  if numel(allwr) == 1
     break
  end
  %-------%
  
  pause(44)
end

disp('done')
%-----------------%
%---------------------------%

%---------------------------%
%-registration to standard space
if ~isempty(cfg.dti.ref)
  bash(['flirt -in ' ddir ngfile ' -ref ' cfg.dti.ref ...
    ' -omat ' bedpostxdir 'xfms/diff2standard.mat -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 12 -cost corratio']);
  bash(['convert_xfm -omat ' bedpostxdir 'xfms/standard2diff.mat -inverse ' bedpostxdir 'xfms/diff2standard.mat']);
end
%---------------------------%

%---------------------------%
%-end log
toc_t = toc(tic_t);
outtmp = sprintf('(p%02.f) %s ended at %s on %s after %s\n\n', ...
  subj, mfilename, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'), ...
  datestr( datenum(0, 0, 0, 0, 0, toc_t), 'HH:MM:SS'));
output = [output outtmp];

%-----------------%
fprintf(output)
fid = fopen([cfg.log '.txt'], 'a');
fwrite(fid, output);
fclose(fid);
%-----------------%
%---------------------------%
