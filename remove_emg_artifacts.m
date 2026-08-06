function [clean_signal, artifact_mask] = remove_emg_artifacts(x, fs, varargin)
% REMOVE_EMG_ARTIFACTS  Detect (and optionally attenuate) impulsive transient
% artifacts in an already band-pass-filtered sEMG signal.

% ALWAYS verify before trusting the result:
%   t = (0:numel(x)-1)/fs;
%   figure; plot(t, x); hold on;
%   yl = ylim;
%   area(t, artifact_mask*yl(2), yl(1), 'FaceAlpha',0.15, 'EdgeColor','none');
%   legend('EMG (post-bandpass)','flagged transient');

% INPUTS
%   x     : band-pass-filtered sEMG (vector), already high-passed at ~20 Hz
%   fs    : sampling rate (Hz)
% NAME-VALUE PARAMETERS
%   'Threshold' (10)   robust-SD multiplier for detection (higher = stricter)
%   'EnvMs'     (25)   moving-RMS window (ms) used to build the energy envelope
%   'MinGapMs'  (50)   merge detections separated by less than this (ms)
%   'PadMs'     (25)   expand each flagged region by this on both sides (ms)
%   'Method'    ('flag') 'flag' leaves signal unchanged (use mask to exclude);
%                        'interp' linearly interpolates across flagged regions;
%                        'zero'  sets flagged regions to 0
% OUTPUTS
%   clean_signal  : signal after the chosen handling (identical to x if 'flag')
%   artifact_mask : logical vector, true where a transient artifact was detected

p = inputParser;
addParameter(p, 'Threshold', 15);
addParameter(p, 'EnvMs',     25);
addParameter(p, 'MinGapMs',  50);
addParameter(p, 'PadMs',     50);
addParameter(p, 'Method',    'flag');
addParameter(p, 'MedianMs', 60);
parse(p, varargin{:});
o = p.Results;

x = x(:);
n = numel(x);

% --- short moving-RMS envelope of instantaneous power -------------------
win = max(1, round(o.EnvMs * 1e-3 * fs));
env = sqrt(movmean(x.^2, win));

% --- robust threshold: median + k * MAD-based sigma --------------------
% Consider using mean instead of median if the trial has long resting
% periods (or breaks).
med   = median(env);

sigma = 1.4826 * median(abs(env - med));   % robust standard deviation
if sigma == 0, sigma = std(env); end       % fallback for flat envelopes
thr   = med + (o.Threshold * sigma);

artifact_mask = env > thr;

% --- merge nearby detections, then pad ---------------------------------
% artifact_mask = local_close_gaps(artifact_mask, round(o.MinGapMs*1e-3*fs));
% artifact_mask = local_dilate(artifact_mask,    round(o.PadMs   *1e-3*fs));

% --- apply chosen handling ---------------------------------------------
clean_signal = x;
switch lower(o.Method)
    case 'flag'
        % Do nothing to the signal (signal untouched).
        % Just use artifact_mask later to exclude these samples from analysis.
    case 'zero'
        % Set artifact samples to 0. AVOID: creates sharp jumps (discontinuities)
        % that can look worse than the original artifact.
        clean_signal(artifact_mask) = nan; %--- AVOID IT
    case 'interp'
        % Fill artifact samples by connecting the good samples around them
        % with a smooth curve (pchip interpolation). Fabricates values,
        % but at least avoids sharp jumps.
        idx = (1:n)';
        if any(~artifact_mask) && any(artifact_mask)
            clean_signal(artifact_mask) = interp1( ...
                idx(~artifact_mask), x(~artifact_mask), ...
                idx(artifact_mask), 'spline', 0);
        end
    case 'fillhole'
        % Set artifact samples to one fixed value (mean + 1 SD of the
        % envelope). AVOID: Creates discontinuities (as 'zero') just a different level.
        clean_signal(artifact_mask) = mean(env) + std(env); %--- AVOID IT
    case 'noisefill'
        % Replace artifact samples with random noise, scaled to match the
        % amplitude of the signal just before/after the artifact.
        edges = find(diff([false; artifact_mask(:); false]));
        starts = edges(1:2:end); ends = edges(2:2:end) - 1;
        for k = 1:numel(starts)
            s = starts(k); e = ends(k); len = e - s + 1;
            
            ctx = round(0.02*fs); % use 20 ms before/after as context
            pre  = x(max(s-ctx,1):s-1);
            post = x(e+1:min(e+ctx,n));
            
            local_amp = std([pre; post]);        % amplitude to match
            if isempty(local_amp) || local_amp == 0
                local_amp = std(env);             % fallback if no context
            end
            
            noise = randn(len,1) * local_amp;     % fake but plausible noise
            clean_signal(s:e) = noise;
        end        
    case 'medianfilt'
        % ------------ Moving-median artifact-trace subtraction ------------
        % Model: x(t) = y(t) [EMG] + n(t) [artifact]
        % movmedian(x) ~ n(t): tracks slow artifact drift, ignores fast
        % EMG fluctuations. Subtract it to recover y(t).
        % Good for slow drift; does NOT work on short high-amplitude
        % spikes (median can't "see" a brief spike) -- use medianfilt_soft.
        
        win_med = max(3, round(o.MedianMs * 1e-3 * fs));
        if mod(win_med, 2) == 0, win_med = win_med + 1; end  % window must be odd
        
        artifact_trace = movmedian(x, win_med);   % n_hat(t): estimated artifact
        
        % Only touch samples inside flagged regions -- leave clean EMG as-is.
        edges  = find(diff([false; artifact_mask(:); false]));
        starts = edges(1:2:end);
        ends   = edges(2:2:end) - 1;
        
        for k = 1:numel(starts)
            s = starts(k); e = ends(k);
            % Subtract the estimated artifact trace from the raw signal.
            % This removes the slow drift/contamination while leaving
            % whatever faster EMG-like content.
            clean_signal(s:e) = x(s:e) - artifact_trace(s:e); % remove artifact estimate
        end
    case 'gaussian_smooth'
        % Gaussian-weighted moving average, used as the local artifact
        % estimate and substituted directly into flagged samples.
        % Related to the moving-average trace method (Conforto & D'Alessio,
        % 1999), using a Gaussian kernel instead of a flat average for
        % smoother transitions. A short window (here 20 samples) keeps it
        % from being swallowed by wide artifacts -- narrow enough to blend
        % the spike down.
        smoothed_signal = smoothdata(x, 'gaussian', 20); % Around 10 ms;
        clean_signal(artifact_mask) = smoothed_signal(artifact_mask);

    case 'hampel'
        % Hampel filter: replaces outliers (deviating from a local median
        % by more than k * MAD) with the local median. Standard, well-cited
        % robust outlier filter (Hampel, 1974; Pearson et al., 2016).
        win_samples = max(3, round(o.MedianMs * 1e-3 * fs));
        clean_signal = hampel(x, win_samples, o.Threshold);
        
    otherwise
        error('remove_emg_transients:Method', ...
            'Unknown Method "%s" (use flag | interp | zero).', o.Method);
end

end

% -------------------------------------------------------------------------
function m = local_close_gaps(m, g)
% Fill gaps of <= g samples between adjacent detected regions.
if g <= 0, return; end
d      = diff([0; m(:); 0]);
starts = find(d ==  1);
ends   = find(d == -1) - 1;
for k = 1:numel(starts)-1
    if starts(k+1) - ends(k) - 1 <= g
        m(ends(k):starts(k+1)) = true;
    end
end
end

% -------------------------------------------------------------------------
function m = local_dilate(m, pad)
% Expand each true region by pad samples on both sides.
if pad <= 0, return; end
kernel = ones(2*pad + 1, 1);
m = conv(double(m(:)), kernel, 'same') > 0;
end

%%%----- Literature
% 1) Conforto & D'Alessio
% https://www.sciencedirect.com/science/article/pii/S1050641198000236