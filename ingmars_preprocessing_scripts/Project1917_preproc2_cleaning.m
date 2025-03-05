function Project1917_preproc2_cleaning(parms)
% Project 1917
% preprocessing script 1 - bad channel and segment detection

% loop over subjects
for isub = parms.subjects

    % set paths
    rootdir = '\\cimec-storage5.unitn.it\MORWUR\Projects\INGMAR\Project1917';
    datadir = sprintf('%s%sdata%ssub-%03d',rootdir,filesep,filesep,isub);
    indir = sprintf('%s%spreprocessing',datadir,filesep);

    % start up Fieldtrip
    addpath('\\cimec-storage5.unitn.it\MORWUR\Projects\INGMAR\toolboxes\fieldtrip-20231220')
    ft_defaults

    % loop over runs
    for irun = parms.runs

        fn2load = sprintf('%s%sdata_reref_filt_trim_sub%03d_run%02d',indir,filesep,isub,irun);
        load(fn2load,'data');

        % filter for segment outliers in the frequency range we're interested
        % in for now (i.e., max beta, or below 50)
        cfg = [];
        cfg.lpfilter = 'yes';
        cfg.lpfreq = 50;

        data_filt = ft_preprocessing(cfg, data);

        % segment continuous data into 500 msec 'fake trials'
        cfg = [];
        cfg.length               = .5;
        data_segmented           = ft_redefinetrial(cfg, data_filt);
        clear data_filt

        cfg = [];
        cfg.channel = {'MEG'};
        cfg.method = 'summary';
        cfg.layout = 'CTF275.lay';
        cfg.keeptrial   = 'yes';
        data_segmented = ft_rejectvisual(cfg, data_segmented);

        % store which channels to keep
        megchan_keep = data_segmented.label;
        fn2save = sprintf('%s%sbadchan_sub%03d_run%02d',indir,filesep,isub,irun);
        save(fn2save, 'megchan_keep');

        % extract bad segments from first test
        BAD_lowfreq = data_segmented.cfg.artfctdef.summary.artifact-data_segmented.sampleinfo(1,1)+1;
        clear data_segmented

        % filter for muscle activity, cut into 500 msec segments, and run ft_rejecvisual summary again
        cfg = [];
        cfg.bpfilter = 'yes';
        cfg.bpfreq = [110 140];
        cfg.bpfilttype = 'but';
        cfg.bpfiltord = 4;
        cfg.hilbert = 'yes';
        cfg.channel = megchan_keep;

        data_filt = ft_preprocessing(cfg, data);

        % segment continuous data into 500 msec 'fake trials'
        cfg                      = [];
        cfg.length               = .5;
        data_segmented           = ft_redefinetrial(cfg, data_filt);
        clear data_filt

        cfg = [];
        cfg.channel = {'MEG'};
        cfg.method = 'summary';
        cfg.layout = 'CTF275.lay';
        cfg.keepchannel = 'yes';
        cfg.keeptrial   = 'yes';
        data_segmented = ft_rejectvisual(cfg, data_segmented);

        % extract bad segments
        BAD_muscle = data_segmented.cfg.artfctdef.summary.artifact-data_segmented.sampleinfo(1,1)+1;
        clear data_segmented

        % convert from indices to time to prevent mistakes later on when
        % removing bad segments on downsampled data
        BAD_lowfreq = data.time{1}(BAD_lowfreq);
        BAD_muscle = data.time{1}(BAD_muscle);

        fn2save = sprintf('%s%sbadseg_sub%03d_run%02d',indir,filesep,isub,irun);
        save(fn2save,'BAD_lowfreq','BAD_muscle');

    end% run loop

end% subject loop
