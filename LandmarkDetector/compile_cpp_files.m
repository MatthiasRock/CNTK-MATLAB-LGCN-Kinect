%% This function compiles the C++ code to a MEX file
function compile_cpp_files()
    %%
    
    % You maybe have to change these paths
    libFolder   = 'C:\repos\cntk\x64\Release';
    libName     = 'Cntk.Core-2.3.1.lib';

    % If the MATLAB version is older than R2018a
    if verLessThan('matlab', '9.4')
        mex('EvaluationMex.cpp',['-L',libFolder],['-l',libName]);
    % If the MATLAB version is R2018a or newer
    else
        mex('EvaluationMex.cpp',['-L',libFolder],['-l',libName],'-R2018a');
    end

end