results_dir = "/Volumes/TIZIANO/results/corr/50Hz_180stim_10sec_100iter_0MNN";
parms=[]
parms.subjects = [3,4];
parms.fsNew = 50;
imod = "dg_map";
iroi = "occ";
upper_y_lim = 0.01

plot_resultss(results_dir, imod,iroi, parms, upper_y_lim)
function plot_resultss(results_directory,imod,iroi,parms, upper_y_lim)
% inputs:
% - results_directory
% - imod
% - parms : .subjects, .fsNew
% - image_dir (where to store the image) ??


figure
freq = round(parms.fsNew);
for irep=[1 2]
    count=0;
    for isub=parms.subjects
        count=count+1;
        % if dist == 0
        fn2load = sprintf('%s/sub%03d/dRSA_corr_sub%03d_%s_%s_rep%d_%dHz.mat', results_directory, isub, isub,imod,iroi,irep,freq);
        
        disp(fn2load)
        %fn2load = sprintf('/Users/tizianocausin/Desktop/dataRepository/RepDondersInternship/results_sanity_check/%02d_23freq_simulation_rep12_%d_iterations_50Hz_no_smooth',isub,100);
        % else
        %     fn2load = sprintf('%s%cdRSA_dist_sub%03d_%s_rep%d_%dHz.mat', results_directory, filesep, isub,imod,irep,freq);
        % end
        load(fn2load)
        storeMod{irep}(count,:)=dRSA;
        dRSApeak1{irep}(isub)=latencytime(dRSA==max(dRSA));
    end
    avgMod{irep}=mean(storeMod{irep});
    sem_mod{irep}=std(storeMod{irep})/sqrt(size(parms.subjects,2));
    peakLatency{irep}=latencytime(avgMod{irep}==max(avgMod{irep}));
end
[hl1 hp1] = boundedline(latencytime,avgMod{1},sem_mod{1}, 'alpha','transparency',.3);
set(hl1,'LineWidth',5);
set(hl1,'color',[0,0.4,.7])
set(hp1,'FaceColor',[0,0.4,.7])
hold on
[hl2, hp2] = boundedline(latencytime,avgMod{2},sem_mod{2},'alpha','transparency',.2);
set(hl2,'LineWidth',5);
set(hl2, 'color',[.6,0,.8]);
set(hp2, 'FaceColor',[.6,0,.8]);
yticks(0:.01:1)
ylim([0 upper_y_lim])
xlim([-5 5])
xline([0 0])
title([imod])
annotation('textbox',[0.15, 0.8, 0.1, 0.1], 'String',['rep1 = ' num2str(peakLatency{1}),'; rep2 = ', num2str(peakLatency{2})])
hold off
end %EOF
