%% theoritical resolution calculations 
c0 = physconst('lightspeed');
delta_x  = 1; % sampling interval x axis (mm)
delta_y = 2; % sampling interval y axis (mm)
aperature_x = 250; % aperature size x axis (mm)
aperature_y = 250; % aperature size x axis (mm)

z0 = 230; % Range of target (range of corresponding image slice) (mm)

F0 = 77e9; % frequency
lambda = (c0/F0)*1e3;
res_x = (lambda*z0)/(2*aperature_x);
res_y = (lambda*z0)/(2*aperature_y);

disp(['theoretic_resolution (x, y) = ' num2str(res_x) ' mm, ' num2str(res_y) ' mm']);
%%



% run script to test the stage movement 

%% connection to the stage 
connect_to_stage; % connect to the stage 


%{
%% Move to intial distance
samplingSpeed = 20000; % sampling jog speed (8mm/sec) 
initialDistance_mm = 50; % distance to be moved (mm)
%move_A(jog_speed, distance_mm, serial_comm)
%move_A(samplingSpeed, initialDistance_mm, s); % move in x axis
%move_B(samplingSpeed, initialDistance_mm, s); % move in y axis

% both move_A and move_B are put into one script
% use this measure distance to the target
moveInitial_AB(samplingSpeed, initialDistance_mm, s); % move the stage to initial position
%}
%% Move to the center of virtual aperature
samplingSpeed = 20000; % sampling jog speed (8mm/sec) 
aperature_length_xy = 250; % aperature length in x (assume x=y) (mm)
centerDistance_mm = (50 + aperature_length_xy)/2; % distance to the center (mm)

moveInitial_AB(samplingSpeed, centerDistance_mm, s);
%% Home the stage 
home_stage; % move to the stage to left-bottom corner