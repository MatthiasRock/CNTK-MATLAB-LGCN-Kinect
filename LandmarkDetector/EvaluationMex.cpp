/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Tested with CNTK 2.3.1, CNTK 2.4 and MATLAB R2016b, R2018a                                                              //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// If you use MATLAB R2016b:                                                                                   //
//		- Comment the Makro 'MATLAB_R2018a'                                                                    //
//		- Compilation in MATLAB: mex -LC:\repos\cntk\x64\Release -lCntk.Core-2.4.lib EvaluationMex.cpp         //
// If you use MATLAB R2018a:                                                                                   //
//		- Uncomment the Makro 'MATLAB_R2018a'                                                                  //
//		- Compilation in MATLAB: mex -LC:\repos\cntk\x64\Release -R2018a -lCntk.Core-2.4.lib EvaluationMex.cpp //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#include <mex.h>
#include <C:\repos\cntk\Source\CNTKv2LibraryDll\API\CNTKLibrary.h>

//#define MATLAB_R2018a

uint32_t times_called = 0;
CNTK::FunctionPtr modelFuncPtr = NULL;

// Main function (called by MATLAB)
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {

    //##################################################
	//#              Get input parameters              #
	//##################################################

	// Input parameter: Images
	#ifdef MATLAB_R2018a
	uint8_t *inImage = mxGetUint8s(prhs[0]);
	#else
	uint8_t *inImage = (uint8_t*)mxGetChars(prhs[0]);
	#endif
	const mwSize *N = mxGetDimensions(prhs[0]);
	
	std::size_t inputDim = mxGetNumberOfDimensions(prhs[0]);

	std::size_t nRows	 = N[0];
	std::size_t nCols	 = N[1];
	std::size_t nSamples = ((inputDim == 3) ? N[2] : 1);

	std::vector<float> inputData(nRows*nCols*nSamples);
	std::vector<float>::iterator inputData_it = inputData.begin();

	for(int sam = 0; sam < nSamples; sam++)
		for(int row = 0; row < nRows; row++)
			for(int col = 0; col < nCols; col++) {
				*inputData_it = float(inImage[row + nRows*(col + sam*nCols)]);
				inputData_it++;
			}
	
	// Input parameter: ModelPath
	std::string tmp(mxArrayToString(prhs[1]));
	std::wstring wModelPath(tmp.begin(), tmp.end());

	// Input parameter: Device
	const CNTK::DeviceDescriptor computeDevice = ((nrhs > 2 && mxArrayToString(prhs[2]) == "CPU") ? CNTK::DeviceDescriptor::CPUDevice() : CNTK::DeviceDescriptor::GPUDevice(0));
	
	//##################################################
	//#                   Load model                   #
	//##################################################

	// If this function is called the first time
	if(++times_called == 1) modelFuncPtr = CNTK::Function::Load(wModelPath, computeDevice);

	// Get input node
	CNTK::Variable inputNode = modelFuncPtr->Arguments()[0];

	// Get output node
	CNTK::Variable outputNode = modelFuncPtr->Outputs()[0];
	
	//##################################################
	//#                    Evaluate                    #
	//##################################################

	// Get shape of input node
	CNTK::NDShape inputShape = inputNode.Shape().AppendShape({nSamples});

	// Input value
	CNTK::ValuePtr inputValue = CNTK::MakeSharedObject<CNTK::Value>(CNTK::MakeSharedObject<CNTK::NDArrayView>(inputShape, inputData, true));

	// Get shape of output node
	CNTK::NDShape outputShape = outputNode.Shape().AppendShape({nSamples});

	// Output value
	CNTK::ValuePtr outputValue;

	// Output map
	std::unordered_map<CNTK::Variable, CNTK::ValuePtr> output_data_map = { { outputNode, outputValue } };

	// Evaluation
	modelFuncPtr->Function::Evaluate({{inputNode, inputValue}}, output_data_map, computeDevice);

	//##################################################
	//#                  Read output                   #
	//##################################################

    std::vector<float> outputData(outputShape.TotalSize());
	std::vector<float>::iterator outputData_it = outputData.begin();

	CNTK::NDArrayViewPtr ArrayOutput = CNTK::MakeSharedObject<CNTK::NDArrayView>(outputShape, outputData, false);

	// Copy output values into the vector
	outputValue = output_data_map[outputNode];
	ArrayOutput->CopyFrom(*outputValue->Data());

	std::size_t nLandmarks  = outputData.size() / (nRows*nCols*nSamples);
	const mwSize outDims[4] = {(const mwSize)nRows,(const mwSize)nCols,(const mwSize)nLandmarks,(const mwSize)nSamples};

	plhs[0] = mxCreateNumericArray(4, outDims, mxDOUBLE_CLASS, mxREAL);
	#ifdef MATLAB_R2018a
	double *out = mxGetDoubles(plhs[0]);
	#else
	double *out = mxGetPr(plhs[0]);
	#endif
	
	for(int lm = 0; lm < nLandmarks; lm++)
		for(int sam = 0; sam < nSamples; sam++)
			for(int col = 0; col < nCols; col++)
				for(int row = 0; row < nRows; row++) {
					out[row + nRows*(col + nCols*(sam + lm*nSamples))] = *outputData_it;
					outputData_it++;

				}

}