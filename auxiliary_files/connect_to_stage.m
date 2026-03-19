% this script establishe a connection to the stage controller via RS232
comport = 'COM3';
s = serialport(comport,19200);

if s.Port == comport
    disp('Serial port connection successful!!')
end 