function varargout = GUI(varargin)
% GUI MATLAB code for GUI.fig
%      GUI, by itself, creates a new GUI or raises the existing
%      singleton*.
%
%      H = GUI returns the handle to a new GUI or the handle to
%      the existing singleton*.
%
%      GUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI.M with the given input arguments.
%
%      GUI('Property','Value',...) creates a new GUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before GUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to GUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help GUI

% Last Modified by GUIDE v2.5 07-Jun-2018 11:23:23

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GUI_OpeningFcn, ...
                   'gui_OutputFcn',  @GUI_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --- Executes just before GUI is made visible.
function GUI_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GUI (see VARARGIN)

% Choose default command line output for GUI
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% Figure initialization
img_size = [1080,1920,3];
imshow(255*ones(img_size,'uint8'),'Parent',handles.axes1);
set(handles.figure1,'units','normalized','outerposition',[0 0 1 1]);    % Set the figure to full screen
set(handles.axes1,'Unit','normalized','Position',[0 0 1 1]);            % Set the axes to full screen
text(handles.axes1,img_size(2)/2,img_size(1)/2,'Initializing...','FontSize',25,'HorizontalAlignment','center','VerticalAlignment','middle');

% UIWAIT makes GUI wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = GUI_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% You can change this
minibatch_size = 8;
setappdata(handles.figure1,'MaxMinibatchSize',minibatch_size);
set(handles.uipanel4,'Visible','off');  % Comment this if you want to see the minibatch size panel

minibatch_size = min(minibatch_size,getappdata(handles.figure1,'MaxMinibatchSize'));
set(handles.edit2,'String',sprintf('%d',minibatch_size));

setappdata(handles.figure1,'minibatchSize',minibatch_size);
setappdata(handles.figure1,'enable_ModelFitting',get(handles.checkbox1,'Value'));
setappdata(handles.figure1,'show_Landmarks',get(handles.checkbox6,'Value'));
setappdata(handles.figure1,'show_KinLandmarks',get(handles.checkbox2,'Value'));
setappdata(handles.figure1,'show_framerates',get(handles.checkbox5,'Value'));
setappdata(handles.figure1,'show_BoundingBoxes',get(handles.checkbox3,'Value'));
setappdata(handles.figure1,'bboxes_ScaleFactor',str2double(get(handles.edit1,'String')));
setappdata(handles.figure1,'maxIntBBoxes',floor(str2double(get(handles.edit3,'String'))));

main(handles);

% Get default command line output from handles structure
varargout{1} = handles.output;


% --------------------------------------------------------------------
function FileMenu_Callback(hObject, eventdata, handles)
% hObject    handle to FileMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OpenMenuItem_Callback(hObject, eventdata, handles)
% hObject    handle to OpenMenuItem (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
file = uigetfile('*.fig');
if ~isequal(file, 0)
    open(file);
end

% --------------------------------------------------------------------
function PrintMenuItem_Callback(hObject, eventdata, handles)
% hObject    handle to PrintMenuItem (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
printdlg(handles.figure1)

% --------------------------------------------------------------------
function CloseMenuItem_Callback(hObject, eventdata, handles)
% hObject    handle to CloseMenuItem (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
selection = questdlg(['Close ' get(handles.figure1,'Name') '?'],...
                     ['Close ' get(handles.figure1,'Name') '...'],...
                     'Yes','No','Yes');
if strcmp(selection,'No')
    return;
end

delete(handles.figure1)


% --- Executes on button press in pushbutton4 (decrease minibatch size)
function pushbutton4_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

MaxMinibach_size = getappdata(handles.figure1,'MaxMinibatchSize');
minibatch_size   = str2double(get(handles.edit2,'String'));

if isnan(minibatch_size)
    minibatch_size = min(3,MaxMinibach_size);
else
    minibatch_size = floor(minibatch_size) - 1;
end

if minibatch_size < 1
    minibatch_size = 1;
elseif minibatch_size > MaxMinibach_size
    minibatch_size = MaxMinibach_size;
end
set(handles.edit2,'String',sprintf('%d',minibatch_size));
setappdata(handles.figure1,'minibatchSize',minibatch_size);


% --- Executes on button press in pushbutton5 (increase minibatch size)
function pushbutton5_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

MaxMinibach_size = getappdata(handles.figure1,'MaxMinibatchSize');
minibatch_size   = str2double(get(handles.edit2,'String'));

if isnan(minibatch_size)
    minibatch_size = min(3,MaxMinibach_size);
else
    minibatch_size = floor(minibatch_size) + 1;
end

if minibatch_size < 1
    minibatch_size = 1;
elseif minibatch_size > MaxMinibach_size
    minibatch_size = MaxMinibach_size;
end
set(handles.edit2,'String',sprintf('%d',minibatch_size));
setappdata(handles.figure1,'minibatchSize',minibatch_size);

% Minibatch size
function edit2_Callback(hObject, eventdata, handles)
% hObject    handle to edit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

MaxMinibach_size = getappdata(handles.figure1,'MaxMinibatchSize');
minibatch_size   = str2double(get(handles.edit2,'String'));

if isnan(minibatch_size)
    minibatch_size = min(3,MaxMinibach_size);
else
    minibatch_size = floor(minibatch_size);
end

if minibatch_size < 1
    minibatch_size = 1;
elseif minibatch_size > MaxMinibach_size
    minibatch_size = MaxMinibach_size;
end
set(handles.edit2,'String',sprintf('%d',minibatch_size));
setappdata(handles.figure1,'minibatchSize',minibatch_size);


% --- Executes during object creation, after setting all properties (minibatch size)
function edit2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox3 (show bounding boxes)
function checkbox3_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

setappdata(handles.figure1,'show_BoundingBoxes',get(handles.checkbox3,'Value'));


% --- Executes on button press in pushbutton2 (decrease bounding box size)
function pushbutton2_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

scale_factor = str2double(get(handles.edit1,'String'));

if isnan(scale_factor)
    scale_factor = 1.17;
else
    scale_factor = scale_factor - 0.02;
end

if scale_factor < 1.0
    scale_factor = 1.0;
elseif scale_factor > 3.0
    scale_factor = 3.0;
end
set(handles.edit1,'String',sprintf('%.2f',scale_factor));
setappdata(handles.figure1,'bboxes_ScaleFactor',scale_factor);


% --- Executes on button press in pushbutton3 (increase bounding box size)
function pushbutton3_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

scale_factor = str2double(get(handles.edit1,'String'));

if isnan(scale_factor)
    scale_factor = 1.17;
else
    scale_factor = scale_factor + 0.02;
end

if scale_factor < 1.0
    scale_factor = 1.0;
elseif scale_factor > 3.0
    scale_factor = 3.0;
end
set(handles.edit1,'String',sprintf('%.2f',scale_factor));
setappdata(handles.figure1,'bboxes_ScaleFactor',scale_factor);


% Bounding boxes scale factor
function edit1_Callback(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

scale_factor = str2double(get(handles.edit1,'String'));

if isnan(scale_factor)
    scale_factor = 1.17;
end

if scale_factor < 1.0
    scale_factor = 1.0;
elseif scale_factor > 3.0
    scale_factor = 3.0;
end
set(handles.edit1,'String',sprintf('%.2f',scale_factor));
setappdata(handles.figure1,'bboxes_ScaleFactor',scale_factor);


% --- Executes during object creation, after setting all properties (bounding boxes scale factor)
function edit1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox2 (show Kinect landmarks)
function checkbox2_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

setappdata(handles.figure1,'show_KinLandmarks',get(handles.checkbox2,'Value'));


% --- Executes on button press in checkbox1 (enable model fitting)
function checkbox1_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

setappdata(handles.figure1,'enable_ModelFitting',get(handles.checkbox1,'Value'));


% --- Executes on button press in pushbutton6 (show Settings)
function pushbutton6_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% If the "Settings" panel is visible
if strcmpi(get(handles.uipanel5,'Visible'),'on')
    set(handles.uipanel5,'Visible','off');
    set(handles.pushbutton6,'String','Show Settings');
else
    set(handles.uipanel5,'Visible','on');
    set(handles.pushbutton6,'String','Hide Settings');
end

% --- Executes on button press in checkbox5 (show framerates & delay)
function checkbox5_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

setappdata(handles.figure1,'show_framerates',get(handles.checkbox5,'Value'));


% --- Executes on button press in checkbox6 (show landmarks)
function checkbox6_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

setappdata(handles.figure1,'show_Landmarks',get(handles.checkbox6,'Value'));


% --- Executes during object creation, after setting all properties.
function figure1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called


% --- Executes when figure1 is resized.
function figure1_SizeChangedFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

figure_size = getpixelposition(handles.figure1);
set(handles.pushbutton6,'Position',[figure_size(3)-95,figure_size(4)-25,95,25]);
set(handles.uipanel5,'Position',[figure_size(3)-185,figure_size(4)-580,185,545]);

% Number of interpolated bounding boxes
function edit3_Callback(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit3 as text
%        str2double(get(hObject,'String')) returns contents of edit3 as a double

maxIntBBoxes = str2double(get(handles.edit3,'String'));

if isnan(maxIntBBoxes)
    maxIntBBoxes = 2;
else
    maxIntBBoxes = floor(maxIntBBoxes);
end

if maxIntBBoxes < 0
    maxIntBBoxes = 0;
elseif maxIntBBoxes > 50
    maxIntBBoxes = 50;
end
set(handles.edit3,'String',sprintf('%d',maxIntBBoxes));
setappdata(handles.figure1,'maxIntBBoxes',maxIntBBoxes);


% --- Executes during object creation, after setting all properties
function edit3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton7 (increase number of interpolated bounding boxes)
function pushbutton7_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

maxIntBBoxes = str2double(get(handles.edit3,'String'));

if isnan(maxIntBBoxes)
    maxIntBBoxes = 2;
else
    maxIntBBoxes = floor(maxIntBBoxes) + 1;
end

if maxIntBBoxes < 0
    maxIntBBoxes = 0;
elseif maxIntBBoxes > 50
    maxIntBBoxes = 50;
end
set(handles.edit3,'String',sprintf('%d',maxIntBBoxes));
setappdata(handles.figure1,'maxIntBBoxes',maxIntBBoxes);


% --- Executes on button press in pushbutton8 (decrease number of interpolated bounding boxes)
function pushbutton8_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

maxIntBBoxes = str2double(get(handles.edit3,'String'));

if isnan(maxIntBBoxes)
    maxIntBBoxes = 2;
else
    maxIntBBoxes = floor(maxIntBBoxes) - 1;
end

if maxIntBBoxes < 0
    maxIntBBoxes = 0;
elseif maxIntBBoxes > 50
    maxIntBBoxes = 50;
end
set(handles.edit3,'String',sprintf('%d',maxIntBBoxes));
setappdata(handles.figure1,'maxIntBBoxes',maxIntBBoxes);
