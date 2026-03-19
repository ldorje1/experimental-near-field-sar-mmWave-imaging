% this script homes the stage
disp('Homing the stage')
command_String = 'HM; BGAB; AM;';
write(s,command_String,"string");
%disp('Homing complete!')