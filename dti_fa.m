function dti_fa(cfg, subj)
%DTI_FA calculate FA and friends
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
%  .dtifa.tbss: directory name for all FA etc files (if empty, it does not copy)
%  .dtifa.type: type of images to copy to common directory (a cell, as {'FA' 'L1' 'RD'})
%
% INPUT
%  Should be in CFG.DATA/0001/CFG.DTI.MOD/CFG.DTI.COND/ and contain:
%  - PROJNAME_SUBJ_smri_dti(CFG.DTIPREP).nii.gz: DWI images, eventually after preprocessing
%  - PROJNAME_SUBJ_smri_dti.bval: b-values (vector 0 and 1000 usually)
%  - PROJNAME_SUBJ_smri_dti(CFG.BVEC): b-vectors, you should specify the last part of the name with cfg.bvec (can be '.grad', '.bvec', '_orig.grad' etc)
%  - PROJNAME_SUBJ_smri_dti_ng_mask.nii.gz: mask for DWI
%
% OUTPUT
%  - full FA directory in CFG.DATA/0001/CFG.DTI.MOD/CFG.DTI.COND/
%  - optionally single-subject image in cfg.dtifa.tbss
%
% Part of DTI
% see also DTI_CONVERT, DTI_PREPROC, DTI_FA, DTI_BEDPOSTX

%---------------------------%
%-start log
output = sprintf('(p%02.f) %s started at %s on %s\n', ...
  subj, mfilename, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'));
tic_t = tic;
%---------------------------%

%---------------------------%
%-dir and files
ddir = sprintf('%s1%03.f/%s/%s/', cfg.data, subj, cfg.dti.mod, cfg.dti.cond); % data directory % XXX remember to change
fadir = [ddir 'fa/']; % FA directory
if isdir(fadir); rmdir(fadir, 's'); end
mkdir(fadir)

file = sprintf('%s_%04.f_%s_%s', cfg.rec, subj, cfg.dti.mod, cfg.dti.cond);

dfile  = [file cfg.dti.dtiprep];
ngfile = [file '_ng_mask']; % brain mask
bvec   = [file cfg.dti.bvec];
bval   = [file '.bval'];
%---------------------------%

%---------------------------%
%-calculate FA
%-------%
%-FA and friends
system(['dtifit -k ' ddir dfile '.nii.gz -m ' ddir ngfile ...
  ' -r ' ddir bvec ' -b ' ddir bval ...
  ' -o ' fadir file]);
%-------%

%-------%
%- create radial diffusivity
system(['fslmaths ' fadir file '_L2 -add ' fadir file '_L3 -div 2 ' fadir file '_RD']);
%-------%
%---------------------------%

%---------------------------%
%-copy DTI data
if ~isempty(cfg.dtifa.tbss)
  
  for i = 1:numel(cfg.dtifa.type)
    
    if strcmp(cfg.dtifa.type{i}, 'FA')
      %-------%
      %-copy FA
      system(['ln ' fadir file '_' cfg.dtifa.type{i} '.nii.gz ' cfg.dtifa.tbss]);
      %-------%
      
    else
      %-------%
      %-copy other measures
      tbssdir = [cfg.dtifa.tbss cfg.dtifa.type{i} filesep];
      if ~isdir(tbssdir); mkdir(tbssdir); end
      
      system(['ln ' fadir file '_' cfg.dtifa.type{i} '.nii.gz ' tbssdir file '_FA.nii.gz']); % it has to be called FA
      %-------%
      
    end
  end
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
