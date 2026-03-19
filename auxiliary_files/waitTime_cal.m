function t = waitTime_cal(JG,D)
%CALCULATE_WAIT_TIME calculates wait time with input jog speed JG (c/s) and
%travel distance D (mm)
%   
%   D :     travel distance in mm
%   JG :    jog speed in counts/sec 
%   speed : (c/s)/(c/mm)=mm/sec

% hardware parameter 
parameter_hardware = 2500; % counts/mm

speed = JG/parameter_hardware; % mm/sec

t = (abs(D))/speed; % sec
end