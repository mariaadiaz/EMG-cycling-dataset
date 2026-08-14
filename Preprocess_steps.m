clear all, clc
%% ---- Define some values
valor_mvc = 1; % 1 = Normalice by max, 2 = Normalize by MVC
fs_delsys = 1926; % Sample frequency EMG
fs_acc = 74; % Sample frequency IMU

%% Select the filepath
filepath = '../Data_cycling/P06'; % This is an example path
fprintf('Subject: %s | Session: %s\n', filepath(end-2:end), 'Cycling');

%% ---- Load the EMG signals
%---- These signals have been filtered using a 4th order butterworth filter band-pass 20-250Hz.
load(fullfile(filepath, 'emg_struct.mat'));
raw_emg = data_struct.raw_emg;
fields = fieldnames(raw_emg);

%% --- Load the envelopes or calculated it using a low pass filter, cut off = 6Hz
%----------------------------%
%----- Load the envelope-----%
%----------------------------%
% envelopes = data_struct.emg_envelopes;

%----------------------------%
%------ Low pass filter------%
%----------------------------%
%---- Define the fnyq
fnyq = round(fs_delsys)/2;
%---- Lowpass to calculate envelope
[b,a] = butter(4,6/fnyq,'low'); % I had 2 order before

%---- Calcualte the envelope for each muscle and add them to one structure
for idx = 2:length(fields)
    signal = raw_emg.(fields{idx});
    rect_signal = abs(signal);
    envelopes.(fields{idx}) = filtfilt(b,a,rect_signal);
end

%% Normalize the envelopes  1 = in magnitude, 2 = MVC
quadMuscles = {'RectusFemoris', 'VastusLateralis', 'VastusMedialis'};

%----------------------------------%
%------ Normalize by the MVC ------%
%----------------------------------%
if valor_mvc == 2
    
    for idx = 2:length(fields)
        m = fields{idx};
        if any(contains(m, quadMuscles))
            normalize_env.(m) = envelopes.(m) ./ data_struct.mvc_values_quads.(m);
        else
            normalize_env.(m) = envelopes.(m) ./ data_struct.mvc_values_hams.(m);
        end
    end
    
else

%----------------------------------%
%---- Normalize by the maximum ----%
%----------------------------------%    
    for idx = 2:length(fields)
        normalize_env.(fields{idx}) = envelopes.(fields{idx}) ./ max(envelopes.(fields{idx}));
    end
    
end

%----------------------------------%
%-- Load the normalized envelope --%
%----------------------------------%
% normalize_env = data_struct.normalized_envelopes;

%% Downsample the signals (if necessary for any processing)
% If you want to downsample the signal, select factor = n. This will
% downsample the signal by keeping every N-th sample.
factor = 1;

for idx = 2:length(fields)
    normalized_envelopes.(fields{idx}) = downsample(normalize_env.(fields{idx}),factor) ;
end
% ---- Time vector considering after downsampling
normalized_envelopes.time = linspace(0,max(raw_emg.time),length(normalized_envelopes.RVastusLateralis));

%% First quick visualization of the data 
figure
ax(1) = subplot(5,1,1);
plot(normalized_envelopes.time,normalized_envelopes.RRectusFemoris),hold on, plot(normalized_envelopes.time,normalized_envelopes.LRectusFemoris)
legend('Right','Left')
title 'Rectus femoris'
ax(2) = subplot(5,1,2);
plot(normalized_envelopes.time,normalized_envelopes.RVastusLateralis), hold on, plot(normalized_envelopes.time,normalized_envelopes.LVastusLateralis)
title 'Vastus lateralis'
ax(3) = subplot(5,1,3);
plot(normalized_envelopes.time,normalized_envelopes.RVastusMedialis), hold on, plot(normalized_envelopes.time,normalized_envelopes.LVastusMedialis)
title 'Vastus medialis'
ax(4) = subplot(5,1,4);
plot(normalized_envelopes.time,normalized_envelopes.RBicepsFemoris), hold on, plot(normalized_envelopes.time,normalized_envelopes.LBicepsFemoris)
title 'Biceps femoris'
ax(5) = subplot(5,1,5);
plot(normalized_envelopes.time,normalized_envelopes.RSemitendinous), hold on, plot(normalized_envelopes.time,normalized_envelopes.LSemitendinous)
title 'Semitendinous'
linkaxes(ax,'x');

%% Organize the cycling file per segment (or block)
%-----------------------------------------%
%-- Extract the 1min segments in a loop --%
%-----------------------------------------%

% Define constants. For P08 I used t_duration = 160 because data is less than 15 mins.
t_duration = 180;  % seconds (3 minutes)
middle_duration = 60;  % seconds (1 minute)

% Total signal duration
t_emg = normalized_envelopes.time;
total_duration = t_emg(end);

% Create the segments structure
number_r = round(total_duration / t_duration);
segments = struct();

count = 0;
% Loop over 3-minute windows
for i = 1 : number_r
    
    % Extract middle 1-minute from 3 minutes block
    middle_start = count*t_duration + (t_duration - middle_duration)/2;
    middle_end = middle_start + middle_duration;
    idx_middle_emg = t_emg >= middle_start & t_emg < middle_end;
    % Store the 1-minute segment
    segments.RRectusFemoris{i}  = normalized_envelopes.RRectusFemoris(idx_middle_emg);
    segments.LRectusFemoris{i}  = normalized_envelopes.LRectusFemoris(idx_middle_emg);
    segments.RVastusLateralis{i} = normalized_envelopes.RVastusLateralis(idx_middle_emg);
    segments.LVastusLateralis{i} = normalized_envelopes.LVastusLateralis(idx_middle_emg);
    segments.RVastusMedialis{i} = normalized_envelopes.RVastusMedialis(idx_middle_emg);
    segments.LVastusMedialis{i} = normalized_envelopes.LVastusMedialis(idx_middle_emg);
    segments.RBicepsFemoris{i} = normalized_envelopes.RBicepsFemoris(idx_middle_emg);
    segments.LBicepsFemoris{i} = normalized_envelopes.LBicepsFemoris(idx_middle_emg);
    segments.RSemitendinous{i} = normalized_envelopes.RSemitendinous(idx_middle_emg);
    segments.LSemitendinous{i} = normalized_envelopes.LSemitendinous(idx_middle_emg);
    segments.time{i} = t_emg(idx_middle_emg);
    count = count + 1;
end

%-----------------------------------%
%-- Load the segments (per block) --%
%-----------------------------------%
%--- The advantage of loading the segments is that it contains IMU data, so
%--- acceleration in the three-axes.
% segments = data_struct.segments;

%% Calculate power and mean activation for all muscles
muscleNames = fields(2:end);
%--- Organize the musccles so in the plot they are next to each other. In
%--- the left panel or the musces from the right and in the right all the ones
%--- from the left.
% muscleNames = {'RRectusFemoris';'LRectusFemoris';'RVastusLateralis';'LVastusLateralis';'RVastusMedialis';'LVastusMedialis';...
%                 'RBicepsFemoris';'LBicepsFemoris';'RSemitendinous';'LSemitendinous'};

% Pre-allocate results struct
results = struct();

% ---- CREATE ONE FIGURE FOR ALL MUSCLES ----
titulo = '';
figure('Color','w','Name',titulo);

%--- Loop over muscles
for m = 1:numel(muscleNames)
    muscle = muscleNames{m};
    trials  = segments.(muscle);
    
    %--- If the muscle is from the right limb use LVastusMedialis to cut
    %--- the signal. If it is from the left limb use the RVastusMedialis
    if muscle(1) == 'R'
        var_cut = segments.LVastusMedialis;
    else
        var_cut = segments.RVastusMedialis;
    end
    if isnumeric(trials)
        nTrials = size(trials,2);
        getTrial = @(k) trials(:,k);
    else
        nTrials = numel(trials);
        getTrial = @(k) trials{k};
    end
    
    results.(muscle).trial(nTrials) = struct();
    
    % ---- set subplot ONCE per muscle (outside trial loop) ----
    ax = subplot(5,2,m);
    cla(ax);                       % clear axes if rerunning
    hold(ax,'on'); grid(ax,'on');
    title(ax, muscle, 'Interpreter','none');
    xlabel(ax,'% cycle'); ylabel(ax,'Normalized EMG');
    
    colors = lines(nTrials);
    
    % ---- I have to iterate through segments, then select the peaks
    for k = 1:nTrials
        %--- Find the peaks to cut
        vals_to_cut = var_cut{k};

        mean_vals_acc = mean(vals_to_cut((vals_to_cut) > 0));
        
        % ---------- 1) PEAK DETECTION ----------
        minPeakDist = round(60/85 * fs_delsys);
        [pks, idx_locs] = findpeaks(vals_to_cut, 'MinPeakProminence', mean_vals_acc, 'MinPeakHeight', mean_vals_acc);
        
        % ---- Take 40 pedals
        idx_locs = idx_locs(1:40); pks = pks(1:40);
        % ---- To visualize peaks, uncomment the line below
%         figure,plot(vals_to_cut),hold on,plot(idx_locs,pks,'*')
        
        % ---------- 2) EXTRACT CYCLES BETWEEN PEAKS ----------
        x = getTrial(k);
        x = x(:);
        short_x = x(idx_locs(1):idx_locs(end));
        nCycles = numel(idx_locs) - 1;
        cycles  = {};
        
        for c = 1:nCycles
            seg = x(idx_locs(c):idx_locs(c+1));
            cycles{c} = seg;
        end
        
        L = round(median(cellfun(@numel, cycles)));
        C = zeros(L, nCycles);
        
        for c = 1:nCycles
            seg = cycles{c};
            tOld = linspace(0,1,numel(seg));
            tNew = linspace(0,1,L);
            C(:,c) = interp1(tOld, seg, tNew, 'linear');
        end
        
        cycleMean = mean(C, 2);
        cycleStd  = std(C, 0, 2);
        cycleLen  = L;
        
        % --------- 3) PLOT MEAN±SD CYCLE FOR THIS TRIAL ---------
        if ~isempty(cycleMean)
            t = linspace(0,100,cycleLen);
            ccol = colors(k,:);
            
            % ---- shaded band
            xfill = [t, fliplr(t)];
            yfill = [(cycleMean - cycleStd).', fliplr((cycleMean + cycleStd).')];
            fill(ax, xfill, yfill, ccol, ...
                'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
                'HandleVisibility','off');
            
            % ---- mean line (legend entry)
            plot(ax, t, cycleMean, 'LineWidth', 1.5, 'Color', ccol, ...
                'DisplayName', sprintf('trial %d', k));
            
            % ---- (Optional) SD dashed lines, keep them off the legend
            plot(ax, t, cycleMean + cycleStd, '--', 'Color', ccol, 'HandleVisibility','off');
            plot(ax, t, cycleMean - cycleStd, '--', 'Color', ccol, 'HandleVisibility','off');
        end
    end
    % ---- Add legend once per muscle subplot ----
    if m == 1
        legend(ax, 'Location','best');
    end
end
