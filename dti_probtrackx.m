function dti_probtrackx(cfg, subj)
%DTI_PROBTRACKX use probtrackx from matlab
%
% CFG
%  .rec: name of the recording
%  .data: name of projects/PROJNAME/subjects/
%  .dti.mod: 'smri' (modality of DTI)
%  .dti.cond: 'dti' (condition of DTI)
%
%  .track.name: name of the tractography session (string)
%  .track.seed: seed mask, full filename (string, obligatory)
%  .track.waypoint: waypoint mask, full filename (string, optional)
%  .track.exclusion: exclusion mask, full filename (string, optional)
%  .track.termination: waypoint mask, full filename (string, optional)
%  .track.opt: extra options to pass to probtrackx
% 
% INPUT
%  One subject-specific folder in smri/dti/ with bedpostx
%  Masks, which are assumed to be in MNI space
%
% OUTPUT
%  folder with calculated probtrackx in .track.name folder within DTI dir
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

opt = [];

%---------------------------%
%-prepare directories
%-----------------%
%-bedpostx directory
ddir = sprintf('%s%04.f/%s/%s/', cfg.data, subj, cfg.dti.mod, cfg.dti.cond); % data directory
beddir = [ddir 'bed/']; % starting directory
bedpostxdir = [beddir(1:end-1) '.bedpostX/'];

opt.s = [bedpostxdir 'merged'];
opt.m = [bedpostxdir 'nodif_brain_mask'];

file = sprintf('%s_%04.f_%s_%s', cfg.rec, subj, cfg.dti.mod, cfg.dti.cond);

ngfile = [file '_ng'];
%-----------------%

%-----------------%
tractdir = [ddir cfg.track.name filesep];
if isdir(tractdir); rmdir(tractdir, 's'); end
mkdir(tractdir)
%-----------------%
%---------------------------%
  
%---------------------------%
%-convert masks to subject-space
masktype = {'seed' 'waypoint' 'exclusion' 'termination'};
optname = {'seed' 'waypoints' 'avoid' 'stop'};
for i = 1:numel(masktype)

  if isfield(cfg.track, masktype{i})
    maskfile = cfg.track.(masktype{i});
    [~, maskname, ext] = fileparts(maskfile);
    maskname = [maskname ext];
    system(['flirt -in ' maskfile ' -ref ' ddir ngfile ' -applyxfm -init ' bedpostxdir 'xfms/standard2diff.mat -o ' tractdir maskname]);
    opt.(optname{i}) = [tractdir maskname];
  end
  
end
%---------------------------%

%---------------------------%
%-prepare command
command = 'probtrackx --mode=seedmask ';
%-------%
%-masks
for i = 1:numel(optname)
  if isfield(opt, optname{i})
    command = [command ' --' optname{i} '=' opt.(optname{i})];
  end
end
%-------%

%-------%
%-dir and files
command = [command ' -s ' opt.s];
command = [command ' -m ' opt.m];
command = [command ' --forcedir --dir=' tractdir];
%-------%

%-------%
%-other options (TODO: use defaults and cfg.track.opt)
command = [command ' -l -c 0.2 -S 2000 --steplength=0.5 -P 5000 --opd'];
%-------%
%---------------------------%

%---------------------------%
%-call to probtrackx
system(command);
%output/feedback on analysis
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