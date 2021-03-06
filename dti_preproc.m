function dti_preproc(cfg, subj)
%DTI_PREPROC eddy current and fieldmap (to implement)
% Maybe rotate bvecs, although the differences are very small
%
% CFG
%  .rec: name of the recording
%  .data: name of projects/PROJNAME/subjects/
%  .dti.mod: 'smri' (modality of DTI)
%  .dti.cond: 'dti' (condition of DTI)
%
%  .dti.b0: index of the volume with no gradient applied (use FSL convetion starting at 0)
%  
% INPUT
%  Should be in CFG.DATA/0001/CFG.DTI.MOD/CFG.DTI.COND/ and contain:
%  - PROJNAME_SUBJ_smri_dti.nii.gz: diffusion-weighted images
%  - PROJNAME_SUBJ_smri_magn.nii.gz: magnitude information of fieldmaps (optional)
%  - PROJNAME_SUBJ_smri_phase.nii.gz: phase information of fieldmaps (optional)
%
% OUTPUT
%  - PROJNAME_SUBJ_smri_dti_ng.nii.gz: b0 image from DWI
%  - PROJNAME_SUBJ_smri_dti_ng_mask.nii.gz: mask for DWI
%  - PROJNAME_SUBJ_smri_dti_ec.nii.gz: eddy-current corrected DWI
%
% Part of DTI
% see also DTI_CONVERT, DTI_PREPROC, DTI_FA,
%          DTI_BEDPOSTX, DTI_PROBTRACKX, DTI_TRACKPROPERTIES
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

dfile = sprintf('%s_%04.f_%s_%s', cfg.rec, subj, cfg.dti.mod, cfg.dti.cond); % data
ngfile = [dfile '_ng']; % Not-gradient
ecfile = [dfile '_ec']; % Not-gradient
phfile = sprintf('%s_%04.f_%s_phase.nii.gz', cfg.rec, subj, cfg.dti.mod);
mgfile = sprintf('%s_%04.f_%s_magn.nii.gz', cfg.rec, subj, cfg.dti.mod);
%---------------------------%

%---------------------------%
%-prepare DTI data
%-----------------%
%-get b0 image
bash(['fslroi ' ddir dfile ' ' ddir ngfile ' ' num2str(cfg.dti.b0) ' 1']);
%-----------------%

%-----------------%
%-make mask
bash(['bet ' ddir ngfile ' ' ddir ngfile ' -m -f .3']); % change -f, (no -n because of fugue)
%-----------------%

%-----------------%
%-eddy current correction
bash(['eddy_correct ' ddir dfile ' ' ddir ecfile ' ' num2str(cfg.dti.b0)]);
%-----------------%
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
