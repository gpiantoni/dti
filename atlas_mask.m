function atlas_mask(cfg)
%ATLAS_MASK create atlas from mask
%
% CFG
%  .atlas.mask(1).atlas: name of the WFU atlas, like:
%           - aal_MNI_V4
%           - atlas116
%           - atlas71
%           - TD_brodmann
%           - TD_hemisphere
%           - TD_label
%           - TD_lobe
%           - TD_type
%  .atlas.mask(1).area: name of the areas to include in the mask (one
%  string, or a cell with multiple string, they need to match the name
%  inside the atlas file you chose).
%
%  .atlas.dir: directory to put the mask in
%
%  .dti.ref: template for flirt realignment ('/usr/share/data/fsl-mni152-templates/MNI152_T1_1mm_brain.nii.gz')
%
% INPUT
%  SPM8 with WFU atlas in toolbox
%
% OUTPUT
%  mask with name atlas_area in folder .atlas.dir
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

wfudir = '/data1/toolbox/spm8/toolbox/wfu_pickatlas/MNI_atlas_templates/';

%-------------------------------------%
%-loop over mask
for m = 1:numel(cfg.atlas.mask)
  
  %------------------%
  %-input check
  if ~iscell(cfg.atlas.mask(m).area)
    cfg.atlas.mask(m).area = {cfg.atlas.mask(m).area};
  end
  %------------------%
  
  %------------------%
  %-mask name
  %--------%
  %-atlas name
  if strcmp(cfg.atlas.mask(m).atlas(1:3), 'TD_')
    atlasname = cfg.atlas.mask(m).atlas(4:end);
  elseif strcmp(cfg.atlas.mask(m).atlas(1:3), 'aal')
    atlasname = 'aal';
  else
    atlasname = cfg.atlas.mask(m).atlas;
  end
  %--------%
  
  %--------%
  %-area name
  areaname = '';
  for a = 1:numel(cfg.atlas.mask(m).area)
    areaname = [areaname regexprep(cfg.atlas.mask(m).area{a}, ' ', '')];
  end
  areas = sprintf(' %s,', cfg.atlas.mask(m).area{:});
  %--------%
  
  maskname = [atlasname '_' areaname];
  %------------------%
  
  %----------------------------%
  %-check if mask exist
  if exist([cfg.atlas.dir maskname '.nii.gz'], 'file')
    
    %-------%
    %-output
    outtmp = sprintf('mask %s (atlas: %s; areas: %s) already exists\n', maskname, atlasname, areas);
    output = [output outtmp];
    %-------%
    
  else
    
    %------------------%
    %-read atlas and roi
    wfufile = [wfudir cfg.atlas.mask(m).atlas];
    if ~exist([wfufile '.nii'], 'file')
      error(sprintf('Atlas %s.nii does not exist in %s\n', ...
        cfg.atlas.mask(m).atlas, wfudir));
    end
    
    atl = ft_read_mri([wfufile '.nii']);
    atl.coordsys = 'spm';
    [roi, label] = readwfu(wfufile);
    
    mri = atl;
    mri.anatomy = zeros(mri.dim);
    %------------------%
    
    %------------------%
    %-add ROI
    for a = 1:numel(cfg.atlas.mask(m).area)
      i_label = strcmpi(label, cfg.atlas.mask(m).area{a});  % index of labels
      
      if isempty(i_label ) || numel(find(i_label)) > 1
        error(['ROI name ' cfg.atlas.mask(m).area{a} ' doesn''t match any label'])
      end
      
      i_ROI = roi(i_label);
      
      mri.anatomy(atl.anatomy == i_ROI) = 1;
      
    end
    %------------------%
    
    %------------------%
    %-convert into dti ref space
    refmri = ft_read_mri(cfg.dti.ref);
    
    cfg1 = [];
    cfg1.parameter = 'anatomy';
    mri = ft_sourceinterpolate(cfg1, mri, refmri); % MRI2 XXXX
    %------------------%
    
    %------------------%
    %-write to file
    cfg1 = [];
    cfg1.parameter = 'anatomy';
    cfg1.filename = [cfg.atlas.dir maskname '.nii'];
    ft_sourcewrite(cfg1, mri);
    
    gzip([cfg.atlas.dir maskname '.nii'])
    delete([cfg.atlas.dir maskname '.nii'])
    %------------------%
    
  end
  %----------------------------%
  
end
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

%-------------------------------------%
%-function to read WFU text files
function [c, d] = readwfu(wfufile)

fid = fopen([wfufile '.txt'], 'r');
fgetl(fid); % header

c = [];
d = {};

while 1
  tline = fgetl(fid); % header
  if ~ischar(tline), break, end
  b = textscan(tline, '%d%s%*d%*d%*d%*d%*d%*d%*d%*d', 'delimiter', '\t');
  c = [c b{1}];
  d = [d b{2}];
end
fclose(fid);
%-------------------------------------%