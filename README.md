# EMG-cycling-dataset
Surface EMG dataset of thigh muscles recorded during an incremental cycling exercise test, with processing and analysis scripts.

This repository includes custom MATLAB (.m) scripts to preprocess the EMG signals and run the analysis steps described in the associated paper. For details on data collection, contents, and file structure, see the dataset repository and the corresponding paper.

The following function takes you to the preprocessing steps and therefore the data available in the dataset. The idea is that you can start with either the raw signal or the EMG envelopes that are already segmented.
**_Preprocess steps:_** Take you.



The following functions are used to preprocess an EMG signal:

> **_Preprocess envelope:_** Delete spikes from EMG signals.
> 
> **_remove_emg_artifacts:_** Identify the EMG envelope. Two different approaches are available, more details are directly in the function.
>
> **_Notch filter:_**  In this folder you will find a number of functions necessary to extract <ins>muscle synergies</ins> and a GUI that can be used not only to extract muscle synergies but also as a tool to compare to a reference set of muscle synergies.
>
> Specific INPUTS and OUTPUTS for each function are defined in each function.



If you have questions about the code, please contact Maria Alejandra Diaz for more info at <ma.diaz@vub.be>.
