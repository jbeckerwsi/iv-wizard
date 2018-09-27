function varargout = iv_wizard(varargin)
% IV_WIZARD MATLAB code for iv_wizard.fig
%      IV_WIZARD, by itself, creates a new IV_WIZARD or raises the existing
%      singleton*.
%
%      H = IV_WIZARD returns the handle to a new IV_WIZARD or the handle to
%      the existing singleton*.
%
%      IV_WIZARD('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in IV_WIZARD.M with the given input arguments.
%
%      IV_WIZARD('Property','Value',...) creates a new IV_WIZARD or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before iv_wizard_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to iv_wizard_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help iv_wizard

% Last Modified by GUIDE v2.5 27-Sep-2018 15:10:51

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @iv_wizard_OpeningFcn, ...
                   'gui_OutputFcn',  @iv_wizard_OutputFcn, ...
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

% --- Executes just before iv_wizard is made visible.
function iv_wizard_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to iv_wizard (see VARARGIN)

% Choose default command line output for iv_wizard
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% This sets up the initial plot - only do when we are invisible
% so window can get raised using iv_wizard.
if strcmp(get(hObject,'Visible'),'off')
    plot(rand(5));
    box on;
    grid on;
    ylabel('Current (A)');
    xlabel('Voltage (V)');
end
getAvailableDrivers();


function getAvailableDrivers
    global availableDrivers;
    if isempty(availableDrivers)
        l=instrhwinfo('matlab');
        availableDrivers=sort(l.InstalledDrivers);
        if numel(availableDrivers) == 0
            availableDrivers={'knick_s252','yokogawa_7651','keithley_2000_beta'};
        end
    end


% UIWAIT makes iv_wizard wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = iv_wizard_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% --- Executes on button press in start.
function start_Callback(hObject, eventdata, handles)
% hObject    handle to start (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global i;
global I;
global Vsample;

axes(handles.axes1);
cla;
set(handles.start,'Enable','off');
set(handles.stop, 'Enable','on');

sweepFrom=1E-3*str2num(get(handles.sweepFrom,'String'));
sweepTo  =1E-3*str2num(get(handles.sweepTo  ,'String'));
sweepStep=1E-3*str2num(get(handles.sweepStep,'String'));

sweepStep=abs(sweepStep);
if sweepFrom > sweepTo
    sweepStep=-sweepStep;
end
V=sweepFrom:sweepStep:sweepTo;
if get(handles.hysteresis,'Value') > 0.5
    V=[V fliplr(V)];
end

complianceUpper  =1E-6*str2num(get(handles.complianceUpper,'String'));
complianceLower  =1E-6*str2num(get(handles.complianceLower,'String'));
complianceEnable =get(handles.complianceEnable,'Value');

voltageDivider  =1/str2num(get(handles.voltageDivider,'String'));
Vsample=V*voltageDivider;

%obtain preamp-setting
popup_sel_index = get(handles.preampSetting, 'Value');
settings=[1E-3 1E-4 1E-5 1E-6 1E-7 1E-8 1E-9 1E-10 1E-11];
preampSetting=settings(popup_sel_index);

global availableDrivers;
instrreset;
global R;
R=Rack('ni');
R.add('V',get(handles.instrument_voltage_visa,'String'),strcat(availableDrivers{get(handles.instrument_voltage_driver,'Value')}, '.mdd'));
%R.add('V','GPIB0::11::INSTR','yokogawa_7651.mdd');

R.add('DMM',get(handles.instrument_current_visa,'String'),strcat(availableDrivers{get(handles.instrument_current_driver,'Value')}, '.mdd'));

connect(R);

R.V.range=max(abs(sweepFrom),abs(sweepTo));
R.DMM.range=10;
R.DMM.nplc=2;
%KE.Trigger.init_continuous=0;

try 
    invoke(R.V,'goSlowTo',sweepFrom,1);
    pause(1.2);
catch
    for Vtemp=linspace(0,sweepFrom,5);
        R.V.value=Vtemp;
        pause(0.05);
    end
end

pause(0.1);

I=NaN(size(Vsample));

if preampSetting < 1E-10
    yScaling=1E12;
    yScalingText='(pA)';
elseif preampSetting < 1e-7
    yScaling=1E9;
    yScalingText='(nA)';
else
    yScaling=1E6;
    yScalingText='(uA)';
end
    
for i=1:numel(V);
    R.V.value=V(i);
    pause(0.1);
    Vin(i)=invoke(R.DMM,'getX');
    I(i)=Vin(i)*-preampSetting;
    
    if complianceEnable && (I(i) > complianceUpper || I(i) < complianceLower)
        break;
    end
    
    if get(handles.stop, 'value')
        set(handles.stop, 'value',0);
        break;
    end
    
    plot(Vsample(1:i)*1E3,I(1:i)*yScaling);
    
    idx=find(~isnan(I) & ~isnan(Vsample));
    idx=idx(idx <= i);
    if(numel(idx) > 1)
        
        f=fit(I(idx)',Vsample(idx)','poly1');
        set(handles.linearRegressionDisplay,'String',sprintf('R=%.3e Ohm',f.p1));
        if f.p1 < 0
            handles.linearRegressionDisplay.ForegroundColor=[1 0 0];
        else
            handles.linearRegressionDisplay.ForegroundColor=[0 0 0];
        end
    end
    
    box on;
    grid on;
    ylabel(['Current ' yScalingText]);
    xlabel('Voltage (mV)');
end


try 
    invoke(R.V,'goSlowTo',0,1);
    pause(1.2);
catch
    for Vtemp=linspace(R.V.value,0,5);
        R.V.value=Vtemp;
        pause(0.05);
    end
end


disconnect(R);

set(handles.start,'Enable','on');
set(handles.stop, 'Enable','off');

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


% --- Executes on selection change in popupmenu1.
function popupmenu1_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns popupmenu1 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu1


% --- Executes during object creation, after setting all properties.
function popupmenu1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
     set(hObject,'BackgroundColor','white');
end

%set(hObject, 'String', {'1E-6 V/A','1E-7 V/A','1E-8 V/A','1E-9 V/A'});


% --- Executes on selection change in popupmenu2.
function popupmenu2_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu2 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu2


% --- Executes during object creation, after setting all properties.
function popupmenu2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in preampSetting.
function preampSetting_Callback(hObject, eventdata, handles)
% hObject    handle to preampSetting (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns preampSetting contents as cell array
%        contents{get(hObject,'Value')} returns selected item from preampSetting


% --- Executes during object creation, after setting all properties.
function preampSetting_CreateFcn(hObject, eventdata, handles)
% hObject    handle to preampSetting (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in stop.
function stop_Callback(hObject, eventdata, handles)
% hObject    handle to stop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



function sweepFrom_Callback(hObject, eventdata, handles)
% hObject    handle to sweepFrom (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of sweepFrom as text
%        str2double(get(hObject,'String')) returns contents of sweepFrom as a double


% --- Executes during object creation, after setting all properties.
function sweepFrom_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sweepFrom (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function sweepTo_Callback(hObject, eventdata, handles)
% hObject    handle to sweepTo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of sweepTo as text
%        str2double(get(hObject,'String')) returns contents of sweepTo as a double


% --- Executes during object creation, after setting all properties.
function sweepTo_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sweepTo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function sweepStep_Callback(hObject, eventdata, handles)
% hObject    handle to sweepStep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of sweepStep as text
%        str2double(get(hObject,'String')) returns contents of sweepStep as a double


% --- Executes during object creation, after setting all properties.
function sweepStep_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sweepStep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function complianceUpper_Callback(hObject, eventdata, handles)
% hObject    handle to complianceUpper (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of complianceUpper as text
%        str2double(get(hObject,'String')) returns contents of complianceUpper as a double


% --- Executes during object creation, after setting all properties.
function complianceUpper_CreateFcn(hObject, eventdata, handles)
% hObject    handle to complianceUpper (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function complianceLower_Callback(hObject, eventdata, handles)
% hObject    handle to complianceLower (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of complianceLower as text
%        str2double(get(hObject,'String')) returns contents of complianceLower as a double


% --- Executes during object creation, after setting all properties.
function complianceLower_CreateFcn(hObject, eventdata, handles)
% hObject    handle to complianceLower (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in complianceEnable.
function complianceEnable_Callback(hObject, eventdata, handles)
% hObject    handle to complianceEnable (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of complianceEnable



function voltageDivider_Callback(hObject, eventdata, handles)
% hObject    handle to voltageDivider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of voltageDivider as text
%        str2double(get(hObject,'String')) returns contents of voltageDivider as a double


% --- Executes during object creation, after setting all properties.
function voltageDivider_CreateFcn(hObject, eventdata, handles)
% hObject    handle to voltageDivider (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in save.
function save_Callback(hObject, eventdata, handles)
% hObject    handle to save (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global filename;
global path;
if ~exist('filename') || isempty(path) 
    path='C:\data\';
    filename='data.txt';
end

global i;
global Vsample;
global I;

if ~exist('i') || ~isnumeric(i) || all(i<1)
    errordlg('I am sorry, but there is no data...');
    return
end

[filename_new, path_new]=uiputfile({'*.txt';'*.dat'},'Save data as...',strcat(path,filename));
if filename_new ~=0 %user hit abort
    filename=filename_new;
    path=path_new;
    T=table(Vsample(1:i)',I(1:i)','VariableNames',{'Voltage_V','Current_A'});
    writetable(T,strcat(path,filename),'Delimiter','\t','FileType','text');
end



function instrument_voltage_visa_Callback(hObject, eventdata, handles)
% hObject    handle to instrument_voltage_visa (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of instrument_voltage_visa as text
%        str2double(get(hObject,'String')) returns contents of instrument_voltage_visa as a double


% --- Executes during object creation, after setting all properties.
function instrument_voltage_visa_CreateFcn(hObject, eventdata, handles)
% hObject    handle to instrument_voltage_visa (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in instrument_voltage_driver.
function instrument_voltage_driver_Callback(hObject, eventdata, handles)
% hObject    handle to instrument_voltage_driver (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns instrument_voltage_driver contents as cell array
%        contents{get(hObject,'Value')} returns selected item from instrument_voltage_driver


% --- Executes during object creation, after setting all properties.
function instrument_voltage_driver_CreateFcn(hObject, eventdata, handles)
% hObject    handle to instrument_voltage_driver (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
getAvailableDrivers();
global availableDrivers;
hObject.String=availableDrivers;
idx=find(cellfun(@(x) strcmp(x,'knick_s252'),availableDrivers));
if ~isempty(idx)
    hObject.Value=idx;
end



function instrument_current_visa_Callback(hObject, eventdata, handles)
% hObject    handle to instrument_current_visa (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of instrument_current_visa as text
%        str2double(get(hObject,'String')) returns contents of instrument_current_visa as a double


% --- Executes during object creation, after setting all properties.
function instrument_current_visa_CreateFcn(hObject, eventdata, handles)
% hObject    handle to instrument_current_visa (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in instrument_current_driver.
function instrument_current_driver_Callback(hObject, eventdata, handles)
% hObject    handle to instrument_current_driver (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns instrument_current_driver contents as cell array
%        contents{get(hObject,'Value')} returns selected item from instrument_current_driver


% --- Executes during object creation, after setting all properties.
function instrument_current_driver_CreateFcn(hObject, eventdata, handles)
% hObject    handle to instrument_current_driver (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
getAvailableDrivers();
global availableDrivers;
availableDrivers
hObject.String=availableDrivers;
try
idx=find(cellfun(@(x) strcmp(x,'keithley_2000_beta'),availableDrivers));
if ~isempty(idx)
    hObject.Value=idx;
end
catch
end


% --- Executes on button press in hysteresis.
function hysteresis_Callback(hObject, eventdata, handles)
% hObject    handle to hysteresis (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of hysteresis
