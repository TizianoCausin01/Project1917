addpath('/Users/tizianocausin/Desktop/programs/fieldtrip-20240110')
ft_defaults
preproc_dir = '/Volumes/TIZIANO/data_preproc';

parms = [];
parms.cluster = 0;
parms.subjects = 3;
parms.ROIs = 2;% 1 = all sensors, 2 = occipito-parietal sensors
parms.fsNew = 50;% sampling frequency to downsample to neural data to
parms.neuralSmoothing = 23;% smoothing in samples, because that's what ft_preproc_smooth uses, should be odd number of samples
parms.MNN = 0; % Multivariate Noise Normalization: 0 = no MNN, 1 = MNN using trials as observations, 2 = MNN using time as observations
parms.rej_bad_muscle = 0;% 0 to keep bad muscle segments in, 1 to reject them
parms.rej_bad_lowfreq = 1;% 0 to keep low-freq noise segments in, 1 to reject them
parms.bad_seg_interp = 1;% 0 to replace bad segments with NaNs and ignore in final analysis, 1 to interpolate
parms.rej_bad_comp = 2;% 1 to remove all bad components, 2 to keep eye-movement components in

subjects = 3:4;
rois = 3:6;
for isub=subjects
    for iroi=rois
        Project1917_preproc5_4TizianoSISSA(preproc_dir, parms,isub,iroi)
    end %for iroi=rois
end % for isub=subjects
function Project1917_preproc5_4TizianoSISSA(preproc_dir, parms,isub,iroi)
% Project 1917
% preprocessing script 4 - ROI selection, dealing with bad channels and bad segments, optionally multivariate noise normalization (MNN), combining runs
%
% if parms.cluster == 1
%     % set paths
%     rootdir = '//mnt/storage/tier2/morwur/Projects/INGMAR/Project1917';
%     % start up Fieldtrip
%     addpath('//mnt/storage/tier2/morwur/Projects/INGMAR/toolboxes/fieldtrip-20231220');
% else
%     % set paths
%     rootdir = '\\cimec-storage5.unitn.it\MORWUR\Projects\INGMAR\Project1917';
%     % start up Fieldtrip
%     addpath('\\cimec-storage5.unitn.it\MORWUR\Projects\INGMAR\toolboxes\fieldtrip-20231220')
% end

% prepare layout
cfg = [];
cfg.layout = '/Users/tizianocausin/Desktop/programs/fieldtrip-20240110/template/layout/CTF275.lay'; %added the full path otherwise it wasn't working
layout = ft_prepare_layout(cfg);
layout = layout.label;

% prepare neighbourhood structure
cfg = [];
cfg.method = 'template';
cfg.template = 'CTF275_neighb.mat';
neighbours = ft_prepare_neighbours(cfg);
indir = sprintf('%s%ssub-%03d%spreprocessing',preproc_dir,filesep,isub, filesep);
outdir = sprintf('%s%ssub-%03d%spreprocessing',preproc_dir,filesep,isub,filesep);

if ~exist(outdir,'dir')
    mkdir(outdir);
end

% remove 'COMNT' and 'SCALE' channel, and remove channels that are missing
% from all runs for this subject
missing_standard = [125 155];
layout([missing_standard end-1:end]) = [];
neighbours(missing_standard) = [];

if iroi == 1
    ROIname = {'allsens'};
    ROIletter = {'M'};
elseif iroi == 2
    ROIname = {'occpar'};
    ROIletter = {'O','P'};
elseif iroi == 3
    ROIname = {'occ'};
    ROIletter = {'O'};
elseif iroi == 4
    ROIname = {'par'};
    ROIletter = {'P'};
elseif iroi == 5
    ROIname = {'tem'};
    ROIletter = {'T'};
elseif iroi == 6
    ROIname = {'fro'};
    ROIletter = {'F'};
end

% load all runs
missingchan = cell(1,6);
for irun = 1:6

    fn2load = sprintf('%s%sdata_reref_filt_trim_sub%03d_run%02d',indir,filesep,isub,irun);
    load(fn2load,'data');

    % remove bad channels
    fn2load = sprintf('%s%sbadchan_sub%03d_run%02d',indir,filesep,isub,irun);
    load(fn2load, 'megchan_keep');

    cfg = [];
    cfg.channel = megchan_keep(:)';
    data = ft_selectdata(cfg, data);

    % remove bad ICA components
    fn2load = sprintf('%s%sica_weights_sub%03d_run%02d',indir,filesep,isub,irun);
    load(fn2load,'unmixing', 'topolabel');

    fn2load = sprintf('%s%sica_badcomps_sub%03d_run%02d',indir,filesep,isub,irun);
    load(fn2load, 'badcomps', 'badcomps_reasons');

    if parms.rej_bad_comp == 2% keep eye movement components in
        eyemovID = strcmp(badcomps_reasons,'eyemov');
        badcomps(eyemovID) = [];
        badcomps_reasons(eyemovID) = [];
    end

    % remove the bad components
    cfg = [];
    cfg.demean = 'no';
    cfg.method = 'predefined unmixing matrix';
    cfg.unmixing = unmixing;
    cfg.topolabel = topolabel;
    data = ft_componentanalysis(cfg, data);

    % reject bad components
    cfg = [];
    cfg.demean = 'no';
    cfg.component = badcomps;
    data = ft_rejectcomponent(cfg, data);

    % smooth with sliding window (Cichy)
    % data.trial{1} = ft_preproc_smooth(data.trial{1},parms.neuralSmoothing);

    % downsample
    cfg = [];
    cfg.resamplefs = parms.fsNew;
    cfg.demean = 'no';
    cfg.detrend = 'no';
    data = ft_resampledata(cfg, data);

    % remove bad segments
    fn2load = sprintf('%s%sbadseg_sub%03d_run%02d',indir,filesep,isub,irun);
    load(fn2load, 'BAD_lowfreq','BAD_muscle');

    % combine two sources of bad segments
    badsegs = [BAD_lowfreq*parms.rej_bad_lowfreq ; BAD_muscle*parms.rej_bad_muscle];
    badsegs(badsegs(:,1) == 0,:) = [];

    for iseg = 1:size(badsegs,1)
        badsegs(iseg,:) = dsearchn(data.time{1}',badsegs(iseg,:)')';
    end

    % create logical vector of samples to keep
    samples2keep = true(size(data.time{1}));
    for iseg = 1:size(badsegs,1)
        samples2keep(badsegs(iseg,1):badsegs(iseg,2)) = false;
    end

    %     % find bad segments larger than 10 sec so they can be excluded from the dRSA analysis
    %     segstart = [];
    %     segend = [];
    %     for isamp = 1:length(samples2keep)-1
    %         if diff(samples2keep(isamp:isamp+1)) == -1
    %             segstart = [segstart isamp+1];
    %         elseif diff(samples2keep(isamp:isamp+1)) == 1
    %             segend = [segend isamp+1];
    %         end
    %     end
    %     largesegID = (segend-segstart)/data.fsample > 10;
    %     segstart(~largesegID) = [];
    %     segend(~largesegID) = [];

    % either replace bad segments with NaNs and ignore in final analysis, or interpolate
    if ~parms.bad_seg_interp
        data.trial{1}(:,~samples2keep) = NaN;
    elseif parms.bad_seg_interp

        tempdata = data.trial{1};
        temptime = data.time{1};
        tempdata(:,~samples2keep) = [];
        temptime(~samples2keep) = [];

        tempdata = interp1(temptime,tempdata',data.time{1},'pchip')';
        data.trial{1} = tempdata;
        clear tempdata temptime
    end

    % make channel selection for this ROI
    chan2sel = contains(layout,ROIletter);

    if any(~contains(layout,data.label))

        % find which channel(s) are missing
        missingchan{irun} = ~contains(layout,data.label);

        % interpolation generally not recommended for MEG data because of different sensor directions relative to a magnetic source, but MNN below
        % doesn't work with NaN, so we interpolate for now. After MNN we can still replace those bad channels with NaNs
        cfg = [];
        cfg.badchannel     = layout(missingchan{irun});
        cfg.method         = 'spline';%'nan';
        cfg.neighbours     = neighbours;
        data = ft_channelrepair(cfg,data);

        % interpolated channel is appended at end of data, move it to
        % correct position
        newid = zeros(size(layout));
        for ichan = 1:length(layout)
            newid(ichan) = find(strcmp(layout{ichan},data.label));
        end

        data.label = data.label(newid);
        data.trial{1} = data.trial{1}(newid,:);

        % select these channels in the missing channel array
        missingchan{irun} = missingchan{irun}(chan2sel);

    end

    % now select channels
    cfg = [];
    cfg.channel = layout(chan2sel);
    data = ft_selectdata(cfg,data);

    if irun == 1
        data_all = data;
    end

    data_all.time{irun} = data.time{1};
    data_all.trial{irun} = data.trial{1};

end% runs

data = data_all;
clear data_all

% decrease file size for storage
% I tested how much we can reduce precision by correlating the uint8 data
% matrix with the original data matrix and the lowest correlation value
% across all time points is is 0.997, but to be safe let's use uint16 precision,
% for which the lowest correlation value was 0.99999995
%
% First we need to rescale the data to the 1-2^16 interval, then it fits in
% the uint16 precision so we can reduce precision (and storage size)
% data_final = cell(6,1);
% for irun = 1:6
%
%     data_final{irun} = single(data.trial{irun});% uint16(rescale(data.trial{irun},1,2^16));
%
% end

% and then store, with some additional info such as time, labels
fn2save = sprintf('%s%ssub%03d_%s_%dHz',...
    outdir,filesep,isub,ROIname{1},parms.fsNew);

save(fn2save,'data', '-v7.3');

end % EOF