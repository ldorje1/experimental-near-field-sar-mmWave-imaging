function move_B(jog_speed, distance_mm, serial_comm)
%UNTITLED6 Summary of this function goes here
%   Detailed explanation goes here

% scale factor 2500counts/mm
s = serial_comm;
counts = 2500 * distance_mm;
command_String = sprintf('JG,%d; PR,%d; BGB; AM;', jog_speed, counts);
write(s,command_String,'string');

end