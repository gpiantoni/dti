function dti_trackproperties(cfg, subj)
%DTI_TRACKPROPERTIES get properties of track
%
% CFG
%  .rec: name of the recording
%  .data: name of projects/PROJNAME/subjects/
%  .dti.mod: 'smri' (modality of DTI)
%  .dti.cond: 'dti' (condition of DTI)
%
%  .track.name: name of the tractography session (string)
%  .track.thr: threshold as ratio to consider a track interesting
%  .track.type: get mean value for DTI model (as in {'FA' 'L1'})
%
% INPUT
%  Folder after DTI_PROBTRACKS with file: fdt_paths.nii.gz
%
% OUTPUT
%  Written output
%  Figure track_hist_SUBJ with histogram of voxels
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
%-read data
ddir = sprintf('%s%04.f/%s/%s/', cfg.data, subj, cfg.dti.mod, cfg.dti.cond); % data directory

%-----------------%
%-directories
fadir = [ddir 'fa/']; % FA directory
file = sprintf('%s_%04.f_%s_%s', cfg.rec, subj, cfg.dti.mod, cfg.dti.cond);

trackdir = [ddir cfg.track.name filesep];
%-----------------%
%---------------------------%

%-----------------------------------------------%
if exist([trackdir 'fdt_paths.nii.gz'], 'file')
  %---------------------------%
  %-get basic parameters
  
  dti = ft_read_mri([trackdir 'fdt_paths.nii.gz']);
  d = dti.anatomy;
  
  m = max(d(:));
  output = sprintf('%sSubj %04.f, %s\n', output, subj, cfg.track.name);
  output = sprintf('%sMax: % 5d\n', output, m);
  
  %-----------------%
  %-distribution of values
  x_magn = 10^ceil(log10(m)); % approx order of magnitude of the number of paths
  %-------%
  %-more robust when there are no tracts at all
  if x_magn == 0
    x_magn = 10;
  end
  %-------%
  hbnd = 0: x_magn/100: x_magn;
  hval = hist(d(:), hbnd);
  y_magn = 10^ceil(log10(max(hval))); % approx order of magnitude of the voxels
  
  semilogy(hbnd, hval, '.')
  xlim(hbnd([1 end]))
  ylim([0 y_magn])
  
  pngname = sprintf('track_hist_%04.f', subj);
  saveas(gcf, [cfg.log filesep pngname '.png'])
  close(gcf); drawnow
  %-----------------%
  %---------------------------%
  
  %---------------------------%
  %-apply threshold
  t = round(cfg.track.thr * m);
  tr = d >= t;
  
  output = sprintf('%sWith a threshold at% 5.2f, there are % 6d voxels with at least% 3d paths\n', ...
    output, cfg.track.thr, numel(find(tr(:))), t);
  %---------------------------%
  
  %---------------------------%
  %-quantify values for FA and friends
  for i = 1:numel(cfg.track.type)
    
    fa = ft_read_mri([fadir file '_' cfg.track.type{i} '.nii.gz']);
    f = fa.anatomy .* tr;
    f(~tr) = NaN;
    
    output = sprintf('%s   Mean %s is %f and median %f\n', ...
      output, cfg.track.type{i},  mean(f(tr(:))), median(f(tr(:))));
    
  end
  %---------------------------%
  
else
  output = sprintf('%sFile fdt_paths.nii.gz in %s does not exist\n', ...
    output, trackdir);
  
end
%-----------------------------------------------%

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