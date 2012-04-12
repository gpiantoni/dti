function dti_convert(cfg, subj)
%DTI_CONVERT: read data from recording folder, convert to nifti
% It uses dcm2nii to convert PAR/REC files. Please, note that dcm2nii
% returns weird file names, which should contain 'DTI' in there. Then, this
% function tries to rename them according to DTI or fieldmaps. It might not
% be completely robust.
%
% You should check that the b0 volume in the DTI file and in the gradient
% files refers to the same volume number (output given follows the FSL
% convertion starting at 0).
%
% CFG
%  .rec: name of the recording
%  .recs: name of recordings/RECNAME/subjects/
%  .data: name of projects/PROJNAME/subjects/
%  .dti.mod: 'smri' (modality of DTI)
%  .dti.cond: 'dti' (condition of DTI)
%  .dti.fieldmap: 'b0' (condition name for fieldmaps. If empty, fieldmaps don't exist)
%
% INPUT
%  This function expects PAR/REC/GRAD in CFG.RECS/0001/CFG.DTI.MOD/raw/
%  It converts the data and copies them into CFG.DATA/0001/CFG.DTI.MOD/CFG.DTI.COND/
%  Furthermore, if it contains fieldmaps, it converts them to NIFTI too.
%  This function is so far specific to the SVUI dataset, especially in
%  handling the gradient. I don't think this is very robust or common.
%
%  If your data is already NIFTI, then do not use this function but copy
%  your data into CFG.DATA/0001/CFG.DTI.MOD/CFG.DTI.COND/
%  
% OUTPUT
%  This function clears and recreates CFG.DATA/0001/CFG.DTI.MOD/CFG.DTI.COND/
%  with converted NIFTI files:
%  - PROJNAME_SUBJ_smri_dti.nii.gz: diffusion-weighted images
%  - PROJNAME_SUBJ_smri_dti.bval: b-values (0 or 1000 usually)
%  - PROJNAME_SUBJ_smri_dti_orig.bvec: b-vectors calculated from PAR file
%  - PROJNAME_SUBJ_smri_dti_orig.grad: from the GRAD file
%  GRAD is the original with the scanner while BVEC is calculated from the
%  PAR (see READ_PAR)
%  - PROJNAME_SUBJ_smri_magn.nii.gz: magnitude information of fieldmaps (optional)
%  - PROJNAME_SUBJ_smri_phase.nii.gz: phase information of fieldmaps (optional)
% 
% Part of DTI
% see also DTI_CONVERT, DTI_PREPROC, DTI_FA, DTI_BEDPOSTX
%          DTI_TBSS, DTI_DESIGN, DTI_RAND

%---------------------------%
%-start log
output = sprintf('(p%02.f) %s started at %s on %s\n', ...
  subj, mfilename,  datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'));
tic_t = tic;
%---------------------------%

%-------------------------------------%
%-dir and files
rdir = sprintf('%s%04.f/%s/%s/', cfg.recs, subj, cfg.dti.mod, 'raw'); % recordings
ddir = sprintf('%s%04.f/%s/%s/', cfg.data, subj, cfg.dti.mod, cfg.dti.cond); % data
if isdir(ddir); rmdir(ddir, 's'); end
mkdir(ddir)
ext = '.nii.gz';
%-------------------------------------%

%-------------------------------------%
%-copy the data into
system(['ln ' rdir cfg.rec '*' cfg.dti.cond '* ' ddir]);
system(['ln ' rdir cfg.rec '*' cfg.dti.fieldmap '* ' ddir]);
%-------------------------------------%

%-------------------------------------%
%-conver the par/rec
%-----------------%
%-unzip
gzfile = dir([ddir '*.gz']);
for g = 1:numel(gzfile)
  gunzip([ddir gzfile(g).name])
  delete([ddir gzfile(g).name])
end
%-----------------%

%-----------------%
%-then use dcm2nii to convert from PAR/REC into nifti
% in preferences, check that it returns "input filename" and output should
% be compressed fsl
system(['dcm2nii -o ' ddir ' -d N -g N -e Y ' ddir '*.PAR']); % don't zip
%-----------------%

%---------------------------%
%-rename
alldti = dir([ddir '*DTI*.nii']); % only DTI

for d = 1:numel(alldti)
  
  if strfind(alldti(d).name, 'DTI_64') % 64 dti data
    cond = 'dti';
  elseif strfind(alldti(d).name, '1x1.nii') % magnitude
    cond = 'magn';
  elseif strfind(alldti(d).name, '1x2.nii') % phase
    cond = 'phase';
  else
    warning('data format not recognized')
  end
  
  newname = sprintf('%s%s_%04.f_%s_%s', ...
   ddir, cfg.rec, subj, cfg.dti.mod, cond);
  disp(newname)
  
  %-----------------%
  %-unzip, rename, zip
  % gunzip([rdir alldti(d).name])
  system(['mv ' ddir alldti(d).name ' ' newname ext(1:4)]);
  gzip([newname ext(1:4)])
  delete([newname ext(1:4)])
  %-----------------%

end
%---------------------------%

%---------------------------%
%-delete rec (to save space)
delete([ddir '*.REC'])
%---------------------------%
%-------------------------------------%

%-------------------------------------%
%-get gradient info from grad or PAR
% The scanner writes down the PAR file with gradient information. At the
% same time, there is a file ending in .GRAD with slighly different
% gradient. I don't know which one is the most accurate, so keep them both
% and compare tractography later on.
dtiname = sprintf('%s_%04.f_%s_%s', cfg.rec, subj, cfg.dti.mod, cfg.dti.cond);
parfile = [dtiname '.PAR'];
if ~exist([ddir parfile], 'file')
  parfile = [dtiname '.par'];
end

if exist([ddir parfile], 'file')
  
  PAR = read_par([ddir parfile]);
  
  %---------%
  %-get volume index (each row is a slice, we just need volumes)
  slidx = [find(diff(PAR.slice_index(:, 43))); size(PAR.slice_index, 1)];
  %---------%
  
  %---------------------------%
  %-bval
  bvals = PAR.slice_index(slidx,34);
  bvalfile = [ddir dtiname '.bval'];
  fbid = fopen(bvalfile, 'w');
  fwrite(fbid, sprintf('%1.f ', bvals));
  fclose(fbid);
  
  outtmp = sprintf('In %s.bval (0-%d), b0 volume is number: %d\n', ...
    dtiname, numel(bvals)-1, find(bvals == 0)-1);
  output = [output outtmp];
  %---------------------------%
  
  %---------------------------%
  %-bvec
  bvecy = -PAR.slice_index(slidx, 46);
  bvecz = PAR.slice_index(slidx, 47);
  bvecx = PAR.slice_index(slidx, 48);
  bvecfile = [ddir dtiname '_orig.bvec'];
  
  fbid = fopen(bvecfile, 'w');
  fwrite(fbid, sprintf('%1.4f\t', bvecx));
  fwrite(fbid, sprintf('\n'));
  fwrite(fbid, sprintf('%1.4f\t', bvecy));
  fwrite(fbid, sprintf('\n'));
  fwrite(fbid, sprintf('%1.4f\t', bvecz));
  fclose(fbid);
  
  outtmp = sprintf('In %s_orig.bvec (0-%d), b0 volume is number: %d\n', ... 
    dtiname, numel(bvecx)-1, find(sum(abs([bvecx bvecy bvecz]), 2) == 0)-1);
  output = [output outtmp];
  %---------------------------%
  
end

%---------------------------%
%-convert GRAD into FSL format
%-----------------%
%-read grad
fid = fopen([ddir dtiname '.grad'], 'r');
gradtxt = textscan(fid, '%f%[:]%f%[,]%f%[,]%f');
fclose(fid);

grad = [gradtxt{3} gradtxt{5} gradtxt{7}]';
grad = grad([3 1 2],:);

dlmwrite([ddir dtiname '_orig.grad'], grad, 'delimiter', '\t')
delete([ddir dtiname '.grad'])

outtmp = sprintf('In %s_orig.grad (0-%d), b0 volume is number: %d\n', ... 
  dtiname, size(grad,2)-1, find(sum(abs([bvecx bvecy bvecz]), 2) == 0)-1);
output = [output outtmp];
%-----------------%
%---------------------------%

%---------------------------%
%-check whether b0 is the first or the last one
[~, act] = system(['fslmeants -i ' ddir dtiname ' -c 57 69 30']);
act = str2num(act);
[B0, iB0] = max(act);
nact = numel(act);

%-------%
%-find second best
act(iB0) = [];
[noB0] = max(act);
%-------%

outtmp = sprintf('In %s.nii.gz (0-%d), b0 volume is likely number: %d (value: % 4.f, second best: % 4.f)\n', ...
  dtiname, nact-1, iB0-1, B0, noB0);
output = [output outtmp];
%---------------------------%
%-------------------------------------%

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