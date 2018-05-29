Detect facial landmarks in Kinect (V2) frames with a trained CNTK network in MATLAB


### General Information

With this code you can visualize the detected landmarks of the LGCN network with CNTK in MATLAB.

Details of the LGCN network can be found in:

Daniel Merget, Matthias Rock, Gerhard Rigoll: "Robust Facial Landmark Detection via a Fully-Convolutional Local-Global Context Network". In: Proceedings of the International Conference on Computer Vision and Pattern Recognition (CVPR), IEEE, 2018.

See also: http://www.mmk.ei.tum.de/cvpr2018/


### Setup Information

Tested with:
	- CNTK 2.3.1, CNTK 2.4
	- MATLAB R2016b, MATLAB R2018a
	- Visual Studio 2017

Requirements:
	- Kinect2 SDK. http://www.microsoft.com/en-us/download/details.aspx?id=44561
	- Add "C:\Program Files\Microsoft SDKs\Kinect\v2.0_1409\bin" to windows path

	
### Kin2 toolbox

Use "compile_cpp_files.m" to create the MEX file.

Citation:
If you find this toolbox useful please cite:
Terven Juan, Cordova-Esparza Diana,  Kin2. A Kinect 2 Toolbox for MATLAB, 
Science of Computer Programming, 2016, http://dx.doi.org/10.1016/j.scico.2016.05.009


### Test image

The data stored in "test_img.mat" is from the FaceGrabber database:

D. Merget, T. Eckl, M. Schwörer, P. Tiefenbacher, and G. Rigoll, "Capturing Facial Videos with Kinect 2.0: A Multithreaded Open Source Tool and Database", in Proc. WACV, IEEE, 2016. 