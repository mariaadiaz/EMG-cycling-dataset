% function [envelope, outliers] = envelope(emg_signal,fs,method,spikes);
%
% This function calculates the envelope of an emg signal 
%
% Inputs:
%         emg_signal - One emg signal    
%         fs         - Sample frequency  
%         method     - Two methods available:
%                      1) Usual: The most common process to calculate 
%                         the envelope from an emg. You can find more 
%                         details in the following package developed 
%                         for Python: pyemgpipeline
%                         pyemgpipeline link: A Python package for EMG processing
%                      2) Literature: Other studies have used that method. 
%                         The reference of the studies are below.
%                         - Jackson, R. W., & Collins, S. H. (2019). 
%                           Heuristic-based ankle exoskeleton control for 
%                           co-adaptive assistance of human locomotion. 
%                           IEEE trans. neural sys. and rehab. engineering
%        spikes     -  Select 'nospikes' if you want to delete the spikes 
%                      from your emg signal. Otherwise input 'spikes' or '0'.
% Outputs:
%         envelope   - QRS complex merge in one signal
%         outliers   -
%
% Maria Alejandra Diaz
% VUB, 2022
% ma.diaz@vub.edu
%
function [envelope,envelope_smooth,rect_signal,outliers] = preprocess_envelope(emg_signal,fs,method,spikes)

fnyq = round(fs)/2;

if strcmp(method,'literature') == 1
    
    % 1. High pass filter
    [b,a] = butter(4,20/fnyq,'high');
    hp_signal = filtfilt(b,a,emg_signal);
    
    % 2. Rectify
    rect_signal = abs(hp_signal);
    
    % 3. Low pass filter
    [b,a] = butter(2,6/fnyq,'low'); % 10 or 6
    envelope = filtfilt(b,a,rect_signal);
    
elseif strcmp(method,'usual') == 1
    % 1. Remove DC
    signal = emg_signal - mean(emg_signal);
    
    % 2. Notch filter — powerline interference (choose 50 or 60 Hz)
    signal = notch_emg(signal, fs, 50);   % Europe

    % 3. Bandpass
    [b,a] = butter(4,[20 450]/fnyq,'bandpass'); % order 4 with Tod Pataky
    filter_signal = filtfilt(b,a,signal); % Frequencies taken from Tod Pataky

    % 4. Remove outliers (artifacts)
    [signal_c, ~] = remove_emg_artifacts(filter_signal, fs, ...
    'Threshold', 17, ...   % robust-SD multiplier; TUNE by overlaying on raw
    'Method',    'gaussian_smooth');  % 'flag' | 'interp' | 'zero' | 'fillhole' | 'gaussian_smooth'

    % 5. Rectify
    rect_signal = abs(signal_c);
    
    % 6. Lowpass envelope
    [b,a] = butter(4,6/fnyq,'low'); % I had 2 order before
    envelope = filtfilt(b,a,rect_signal);
    
%     figure,plot(signal),hold on,plot(envelope,'Linewidth',2)
    
    win = round(0.3*fs);
    envelope_smooth = movmean(envelope, win);    

end

% Delete spikes from the envelope if necessary, extra step if necessary
if strcmp(spikes,'nospikes') == 1
    [envelope,outliers] = remove_emg_spikes(filter_signal, envelope, fs); % Remove spikes  
else
    outliers = [];
end

%--------------------------------------------------------------%
%----------- Other reference that might be relevant -----------%

% McManus (2020) Analysis and Biophysics of Surface EMG for Physiotherapists and
% Kinesiologists: Toward a Common Language With Rehabilitation Engineers

end