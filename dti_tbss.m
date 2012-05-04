function dti_tbss(cfg)
%SWTBSS tbss on EEG parameters
%
% CFG
%  .rec: name of the recording
%  .data: name of projects/PROJNAME/subjects/
%  .dti.mod: 'smri' (modality of DTI)
%  .dti.cond: 'dti' (condition of DTI)
%
%  .dtifa.tbss: directory name for all FA etc files
%  .dtifa.type: type of images to copy to common directory (a cell, as {'FA' 'L1' 'RD'})
% 
%  .tbss.thr: threshold for including FA tracts (default 0.2)
%
% INPUT
%  FA images in the folder cfg.dtifa.tbss with the format
%  - PROJNAME_SUBJ_smri_dti _FA.nii.gz
%  Eventually, other parameters (as defined by cfg.dtifa.type) in
%  subfolders. The subfolder should have the name, f.e. L1 or MD, but the
%  files should be called in the same way as FA files (depends on FSL)
%
% OUTPUT
%  cfg.dtifa.tbss directory is ready for statistics (DTI_DESIGN, DTI_RAND)
%
% Part of DTI
% see also DTI_CONVERT, DTI_PREPROC, DTI_FA,
%          DTI_BEDPOSTX, DTI_PROBTRACKX, DTI_TRACKPROPERTIES
%          DTI_TBSS, DTI_DESIGN, DTI_RAND, ATLAS_MASK

%---------------------------%
%-start log
output = sprintf('%s started at %s on %s\n', ...
  mfilename, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'));
tic_t = tic;
%---------------------------%

%---------------------------%
%-dir and files
fafile = sprintf('%s_*_%s_%s_FA.nii.gz', cfg.rec, cfg.dti.mod, cfg.dti.cond); % fa images
wrfile = sprintf('%s_*_%s_%s_FA_FA_to_target_warp.msf', cfg.rec, cfg.dti.mod, cfg.dti.cond); % wrap file (it's empty till tbss2 has finished)
allfa = dir([cfg.dtifa.tbss fafile]);
%---------------------------%

%---------------------------%
%-tbss
cdir = pwd;
cd(cfg.dtifa.tbss)

%-------%
%-TBSS preproc
bash(['tbss_1_preproc ' sprintf('%s ', allfa(:).name) ]);
% copy images from slicedir?
%-------%

%-------%
%-TBSS registation
bash('tbss_2_reg -T');

while 1
  pause(5)
  
  %-method 1: check if flirt and fnirt are running
  %it fails bc it takes some time to initialize
  [running] = bash('ps -u gpiantoni | grep -c f*irt');
  fprintf(running)
  
  %-method 2: tbss2 creates some empty files and it puts something in it at
  %the end of the computation
  allwr = dir([cfg.dtifa.tbss 'FA/' wrfile]);
  if numel(allwr) > 0 && all([allwr.bytes] ~= 0)
    break
  end
  
  pause(5)
end
disp('done')
%-------%

%-------%
%-TBSS postreg
bash('tbss_3_postreg -S');
%-------%

%-------%
%-TBSS prestats
bash(['tbss_4_prestats ' num2str(cfg.tbss.thr)]);
%-------%

%-------%
%-TBSS: other measures
for i = 1:numel(cfg.dtifa.type)
  if ~strcmp(cfg.dtifa.type{i}, 'FA')
    disp(['computing ' cfg.dtifa.type{i} ])
    bash(['tbss_non_FA ' cfg.dtifa.type{i}]);
  end
end
%-------%

cd(cdir)
%---------------------------%

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
