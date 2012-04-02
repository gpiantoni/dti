function dti_process(cfg, subj)
%PREPRDTI prepare DTI
%
% CFG
%  .rec: name of the recording
%  .data: name of projects/PROJNAME/subjects/
%  .dti.mod: 'smri' (modality of DTI)
%  .dti.cond: 'dti' (condition of DTI)
%  .
%
% INPUT
%  Should be in CFG.DATA/0001/CFG.DTI.MOD/CFG.DTI.COND/ and contain:
%  - PROJNAME_SUBJ_smri_dti.nii.gz: diffusion-weighted images
%  - PROJNAME_SUBJ_smri_dti.bval: b-values (0 or 1000 usually)
%  - PROJNAME_SUBJ_smri_dti_orig.bvec: b-vectors calculated from PAR file
%  - PROJNAME_SUBJ_smri_dti_orig.grad: b-vectors calculated from the GRAD file
%  you can specify which b-vector file you want to use with cfg.bvec
%  - PROJNAME_SUBJ_smri_magn.nii.gz: magnitude information of fieldmaps (optional)
%  - PROJNAME_SUBJ_smri_phase.nii.gz: phase information of fieldmaps (optional)
% 
% OUTPUT
%
%
%

% It's not necessary to rotate the bvec, because the differences are
% extremely small
%
% Part of DTI
% see also DTI_CONVERT, DTI_PROCESS

%---------------------------%
%-start log
output = sprintf('(p%02.f) %s started at %s on %s\n', ...
  subj, mfilename, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'));
tic_t = tic;
%---------------------------%

%---------------------------%
%-dir and files
ddir = sprintf('%s%04.f/%s/%s/', cfg.data, subj, cfg.dti.mod, cfg.dti.cond); % data directory
fadir = [ddir 'fa/']; % FA directory

dfile = sprintf('%s_%04.f_%s_%s', cfg.rec, subj, cfg.dti.mod, cfg.dti.cond); % data
ngfile = [dfile '_ng']; % Not-gradient
phfile = sprintf('%s_%04.f_%s_phase.nii.gz', cfg.rec, subj, cfg.dti.mod);
mgfile = sprintf('%s_%04.f_%s_magn.nii.gz', cfg.rec, subj, cfg.dti.mod);
%---------------------------%

%---------------------------%
%-clean up previous analysis
%-----------------%
% if strcmp(cfg.dti.redoec, 'yes')
%   delete([ddir '*brain*'])
%   delete([ddir '*ng*'])
%   delete([ddir '*_ec*'])
% end
% delete([ddir '*fugue*'])
% delete([ddir 'fieldmap2diff.mat'])

if isdir(fadir); rmdir(fadir, 's'); end
mkdir(fadir)
%-----------------%
%---------------------------%

%---------------------------%
%-prepare DTI data
%-----------------%
%-get names right
origfile = dfile; % to be used for getting gradients and naming FA
if strcmpi(cfg.preprdti.ec, 'yes')
  dfile = sprintf('%s_%s_%04.f_%s_%s_ec', cfg.proj, cfg.rec, subj, cfg.mod2, cfg.cond2); % data
end
%-----------------%

%-----------------%
%-run or skip preparation
if strcmp(cfg.preprdti.redoec, 'yes')
  
  %-------%
  %-get b0 image
  system(['fslroi ' ddir origfile ' ' ddir ngfile ' ' num2str(cfg.preprdti.b0) ' 1']);
  %-------%
  
  %-------%
  %-make mask
  system(['bet ' ddir ngfile ' ' ddir ngfile '_brain -m -f .3']); % change -f, (no -n because of fugue)
  %-------%
  
  
  if strcmpi(cfg.preprdti.ec, 'yes')
    %-------%
    %-eddy current correction
    system(['eddy_correct ' ddir origfile ' ' ddir dfile ' ' num2str(cfg.preprdti.b0)]);
    %-------%
  end
end
%-----------------%
%---------------------------%

%---------------------------%
%-fugue
if strcmpi(cfg.preprdti.fugue, 'yes')
  
  %-transform into rad/s
  system(['fslmaths ' ddir ffile '_phase -div 100 -mul ' sprintf('%1.15f', pi) '  ' ddir ffile '_phase_pi']);
  
  %-extract brain from magnitude
  system(['bet ' ddir ffile '_magn ' ddir ffile '_magn_brain  -f .3 -m']);
  
  %-only use brain for phase info
  system(['fslmaths ' ddir ffile '_phase_pi -mas ' ddir ffile '_magn_brain_mask ' ddir ffile '_phase_brain']);
  
  %-optional: smooth or improve fieldmap (remember to change names down if you use it)
  % system(['fugue --loadfmap=' ddir ffile '_phase_brain -s 4 --savefmap=' ddir ffile '_phase_brain_s4']);
  
  %-unwrap phase (phase is pretty constant in the center of the brain, it needs unwrapping on temporal lobe and orbitofrontal cortex)
  system(['prelude -p ' ddir ffile '_phase_pi -a ' ddir ffile '_magn_brain -m ' ddir ffile '_magn_brain_mask -o ' ddir ffile '_phase_pi']);
  
  %-apply b0 correction to magn (extremely small differences)
  system(['fugue -v -i ' ddir ffile '_magn_brain --unwarpdir=x- --dwell=0.000700777425 --asym=0.005 --loadfmap=' ddir ffile '_phase_pi -w ' ddir ffile '_magn_brain_warped']);
  
  %-realign magnitude to dti image
  system(['flirt -in ' ddir ffile '_magn_brain_warped -ref ' ddir ngfile '_brain -out ' ddir ffile '_magn_brain_warped_2_ng_brain -omat ' ddir 'fieldmap2diff.mat']);
  
  %-apply realignment to phase
  system(['flirt -in ' ddir ffile '_phase_brain -ref ' ddir ngfile '_brain -applyxfm -init ' ddir 'fieldmap2diff.mat -out ' ddir ffile '_phase_brain_dti']);
  
  %-apply fugue
  % system(['fugue -v -i ' ddir dfile ' --icorr --unwarpdir=y --dwell=0.000700777425 --asym=0.005 --loadfmap=' ddir ffile '_phase_brain_dti -u ' ddir dfile '_fugue']);
  % system(['fugue -v -i ' ddir dfile ' --icorr --unwarpdir=x- --dwell=0.0010818 --loadfmap=' ddir ffile '_phase_brain_dti -u ' ddir dfile '_fugue']);% --saveshift=' ddir dfile 'pixelshift']);
  system(['fugue -v -i ' ddir dfile ' --unwarpdir=x- --dwell=0.000700777425 --asym=0.010 --loadfmap=' ddir ffile '_phase_brain_dti -u ' ddir dfile '_fugue']); 
  
  dfile = [dfile '_fugue'];
  
  %-------%
  %-clean up a little bit
  delete([ddir '*phase_*'])
  delete([ddir '*magn_*'])
  %-------%
  
end
%---------------------------%

%---------------------------%
%-calculate FA
%-------%
%-FA and friends
system(['dtifit -k ' ddir dfile ' -m ' ddir ngfile '_brain_mask ' ...
  '-r ' ddir origfile cfg.bvec ' -b ' ddir origfile '.bval ' ...
  '-o ' fadir origfile]);
%-------%

%-------%
%- create radial diffusivity
system(['fslmaths ' fadir origfile '_L2 -add ' fadir origfile '_L3 -div 2 ' fadir origfile '_RD']);
%-------%
%---------------------------%

%---------------------------%
%-copy DTI data
for i = 1:numel(cfg.preprdti.type)
  if strcmp(cfg.preprdti.type{i}, 'FA')
    system(['ln ' fadir origfile '_' cfg.preprdti.type{i} '.nii.gz ' cfg.tbss]);
  else
    if ~isdir([cfg.tbss cfg.preprdti.type{i}]); mkdir([cfg.tbss cfg.preprdti.type{i}]); end
    system(['ln ' fadir origfile '_' cfg.preprdti.type{i} '.nii.gz ' cfg.tbss cfg.preprdti.type{i} filesep origfile '_FA.nii.gz']); % it has to be called FA
  end
end
%---------------------------%

%---------------------------%
if strcmpi(cfg.clean, 'dti') || strcmpi(cfg.clean, 'all')
  delete([ddir '*brain*'])
  delete([ddir '*ng*'])
  delete([ddir '*ec*'])
  delete([ddir '*fugue*'])
  delete([ddir 'fieldmap2diff.mat'])
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
