function moveInitial_AB(jog_speed, distance_mm, serial_comm)
% MOVE_A moves distance distance_mm with speed jog_speed in horizontal   
%UNTITLED5 Summary of this function goes here
%   Detailed explanation goes here

% scale factor 2500counts/mm
s = serial_comm; % serial communication 
counts = 2500 * distance_mm;
command_String = sprintf('JG%d,%d; PR%d,%d; BGAB; AM;', jog_speed, jog_speed, counts, counts);
write(s,command_String,'string');

end