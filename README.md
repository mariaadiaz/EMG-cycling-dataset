# EMG-cycling-dataset
Surface EMG dataset of thigh muscles recorded during an incremental cycling exercise test, with processing and analysis scripts.

This repository includes custom MATLAB (.m) scripts to preprocess the EMG signals and run the analysis steps described in the associated paper. For details on data collection, contents, and file structure, see the dataset repository and the corresponding paper.

The following main script guides users through extracting each of the available datasets (raw → envelope → normalized), allowing you to start from the raw signal or the segmented EMG envelopes.

> **_Preprocess steps:_** Guide the user through the different EMG processing steps filtering → rectification → envelope extraction → normalization → segmentation → Validation.


The following functions are used to preprocess an EMG signal:

> **_Preprocess envelope:_** This function calculates the envelope of an EMG signal. It offers different approaches based on literature, but the "usual" is the preferred. 
> 
> **_remove_emg_artifacts:_** Remove EMG artifacts (high spikes). Detect (and optionally attenuate) impulsive transient artifacts in an already band-pass-filtered sEMG signal.
>
> **_notch_emg:_**  Remove powerline interference from EMG signal
>
> Specific INPUTS and OUTPUTS for each function are defined in each function.



If you have questions about the code, please contact Maria Alejandra Diaz for more info at <ma.diaz@vub.be>.
