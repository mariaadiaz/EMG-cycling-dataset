% NOTCH_EMG  Remove powerline interference from EMG signal
%
% Usage:
%   signal_clean = notch_emg(signal, fs)                    % 50 Hz default
%   signal_clean = notch_emg(signal, fs, 60)                % 60 Hz
%   signal_clean = notch_emg(signal, fs, 50, 2)             % custom bandwidth
%
% Inputs:
%   signal          - raw EMG signal (vector)
%   fs              - sampling frequency (Hz)
%   powerline_freq  - powerline frequency: 50 or 60 Hz (default: 50)
%   bandwidth       - notch bandwidth in Hz (default: 2)
%
% Reference:
%   SENIAM guidelines; De Luca et al. 2010
%
%
% Maria Alejandra Diaz
% VUB, 2026
% ma.diaz@vub.edu
%
function signal_clean = notch_emg(signal, fs, powerline_freq, bandwidth)

    % --- Defaults ---
    if nargin < 3 || isempty(powerline_freq), powerline_freq = 50; end
    if nargin < 4 || isempty(bandwidth),      bandwidth = 2;       end

    % --- Force column vector ---
    was_row      = isrow(signal);
    signal       = signal(:);
    signal_clean = signal;

    % --- Apply notch at fundamental + harmonics ---
    % Harmonics within EMG bandwidth (up to fs/2)
    harmonics = powerline_freq : powerline_freq : fs/2 - 1;

    for f0 = harmonics
        % Quality factor Q: controls notch sharpness
        % Q = f0/bandwidth → higher Q = narrower notch
        Q = f0 / bandwidth;

        % Design notch (bandstop) filter
        wo = f0 / (fs/2);              % normalized frequency
        bw = wo / Q;                   % normalized bandwidth
        [b, a] = iirnotch(wo, bw);     % 2nd order IIR notch

        % Apply zero-phase filtering
        signal_clean = filtfilt(b, a, signal_clean);
    end

    % --- Restore orientation ---
    if was_row, signal_clean = signal_clean'; end
end