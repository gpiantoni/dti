function dti_design(cfg)
%DTI_DESIGN create design matrix for TBSS analysis
%
% CFG
%  .dtifa.tbss: directory name for all FA etc files
%
%  .tbss.des: one or more structures, with fields:
%         .name: name of the contrast
%         .fun: name of the function (see below)
%         .corr: 1 (for positive correlation) or -1 for negative
%                correlation (one value per column of the design matrix)
%         .demean: if your design columns should be demeaned (logical, default is TRUE)
%         .ones: if it adds a column of ones to your design matrix (logical, default is TRUE)
%  The function gets as input the cfg and the index of cfg.tbss.des in the
%  loop. It should return a design matrix. The size of the design matrix is
%  NxC, where N is the number of subjects and C is the number of regressors/contrasts.
%  For example, you can return a random design matrix with two regressors:
%      function [des, output] = des_random(cfg, d)
%      des = randn(numel(cfg.subjall), 2);
%  It's very important that N is equal to numel(cfg.subjall). If you don't
%  analyze some subjects, you should be careful to do:
%    for i = 1:numel(cfg.subjall)
%      des(i, 1) = single subject value
%    end
%  The output 'output' is optional, and will be written to the log file
%
% INPUT
%  Depend on your own function
%
% OUTPUT
%  cfg.dtifa.tbss directory is ready for statistics (DTI_RAND)
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
%-directory with design
desd = [cfg.dtifa.tbss 'design/'];
if isdir(desd); rmdir(desd, 's'); end
mkdir(desd)
%---------------------------%

%---------------------------%
%-check if two designs have the same name
if numel(unique({cfg.tbss.des.name})) ~= numel(cfg.tbss.des)
  output = sprintf('%sWARNING: Some of your designs (cfg.tbss.des) have the same name. The first design will be overwritten\n', output);
end
%---------------------------%

%-------------------------------------%
%-loop over designs
for d = 1:numel(cfg.tbss.des)
  
  %---------------------------%
  %-dir and files
  desfile = [desd cfg.tbss.des(d).name];
  output = [output sprintf('\nContrast: %s\n', cfg.tbss.des(d).name)];
  
  if ~isfield(cfg.tbss.des(d), 'demean') || isempty(cfg.tbss.des(d).demean)
    cfg.tbss.des(d).demean = true;
  end
  if ~isfield(cfg.tbss.des(d), 'ones') || isempty(cfg.tbss.des(d).ones)
    cfg.tbss.des(d).ones = true;
  end
  %---------------------------%
  
  %---------------------------%
  %-run specific function to prepare design
  if nargout(cfg.tbss.des(d).fun) == 1
    des = feval(cfg.tbss.des(d).fun, cfg, d);
  else
    [des outtmp] = feval(cfg.tbss.des(d).fun, cfg, d);
    output = [output outtmp];
  end
  %-----------------%
  %-check input and return values
  if size(des,2) ~= numel(cfg.tbss.des(d).corr)
    output = sprintf('%sWARNING: number of design matrix columns (%d) is different from the number of contrasts(%d)\nSkipping the contrast\n', ...
      output, size(des,2), numel(cfg.tbss.des(d).corr));
    
    continue
  end
  
  output = [output sprintf('Non-demeaned values\n')];
  for i = 1:size(des,2)
    desstr = sprintf('%10.3f', des(:,i));
    output = [output sprintf('contrast #%3d (%2d): %s\n', i, cfg.tbss.des(d).corr(i), desstr)];
  end
  %-----------------%
  
  %-----------------%
  %-demean
  if cfg.tbss.des(d).demean
    des = des - repmat(mean(des), numel(cfg.subjall), 1);
  end
  %-----------------%
  
  %-----------------%
  %-show correlation between columns
  des_corr = corrcoef(des);
  if size(des,2) > 1
    output = [output sprintf('Correlation between regressors\n')];
    for i = 1:size(des_corr,1)
      output = [output sprintf('%6.2f', des_corr(i,:)) sprintf('\n')];
    end
  end
  %-----------------%
  
  %-----------------%
  %-ones
  descon = des; % we use this later to describe the contrasts
  if cfg.tbss.des(d).ones
    des = [ones(size(des,1),1) des];
  end
  %-----------------%
  %---------------------------%
  
  %---------------------------%
  %-write design in FSL format
  %-----------------%
  %-write mat
  fid = fopen([desfile '.mat'], 'w');
  fwrite(fid, sprintf('/NumWaves\t%1.f\n', size(des,2)));
  fwrite(fid, sprintf('/NumPoints\t%1.f\n', size(des,1)));
  
  fwrite(fid, sprintf('/PPheights\t'));
  for c = 1:size(des,2)
    fwrite(fid, sprintf('\t%1.5f', range(des(:,c))));
  end
  fwrite(fid, sprintf('\n\n'));
  
  fwrite(fid, sprintf('/Matrix\n'));
  for s = 1:size(des,1)
    fwrite(fid, sprintf('%1.5f ', des(s,:)));
    fwrite(fid, sprintf('\n'));
  end
  
  fclose(fid);
  %-----------------%
  
  %-----------------%
  %-contrast
  %-------%
  %-write con
  fid = fopen([desfile '.con'], 'w');
  for c = 1:size(descon,2)
    fwrite(fid, sprintf('/ContrastName%1.f\t"con%1.f"\n', c, c));
  end
  
  fwrite(fid, sprintf('/NumWaves\t%1.f\n', size(des,2)));
  fwrite(fid, sprintf('/NumContrasts\t%1.f\n', size(descon,2)));
  
  fwrite(fid, sprintf('/PPheights\t'));
  for c = 1:size(descon,2)
    fwrite(fid, sprintf('\t%1.5f', range(descon(:,c))));
  end
  fwrite(fid, sprintf('\n'));
  
  printones = sprintf('%1.f ', ones(size(descon,2),1));
  fwrite(fid, sprintf('/RequiredEffect\t\t%s\n\n', printones));
  
  fwrite(fid, sprintf('/Matrix\n'));
  
  coneye = diag(cfg.tbss.des(d).corr);
  
  for c = 1:size(descon,2)
    
    if cfg.tbss.des(d).ones
      printcon = ['0 ' sprintf('%1.f ', coneye(c,:))];
    else
      printcon = sprintf('%1.f ', coneye(c,:));
    end
    
    fwrite(fid, sprintf('%s\n', printcon));
  end
  fclose(fid);
  %-----------------%
  %---------------------------%
  
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