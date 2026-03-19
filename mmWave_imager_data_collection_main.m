%% Near-Field SAR Data Collection Script
% This script:
% 1) Connects to the motion stage and mmStudio
% 2) Loads the radar sensor configuration from a Lua file
% 3) Configures the SAR scan geometry
% 4) Creates an output folder for raw ADC data
% 5) Runs either a 2D rectangular scan or a 1D linear scan
% 6) Returns the stage to home position after acquisition

%% Initialization
mainDir = pwd;   % Save current working directory

% Connect to hardware
connect_to_stage;      % Connect to motion stage
connect_to_mmStudio;   % Connect to TI mmStudio

%% mmWave Radar Sensor Configuration
% Load sensor parameters using the mmStudio Lua configuration file
sensorConfigLua = fullfile( ...
    'C:\Users\Dorje\OneDrive\Desktop\Research Lhamo\R1_AB_TI_imaging_system\TI_mmWave_code_V2', ...
    'initial_mmStudio_setup.lua');

luaCommand = sprintf('dofile("%s")', sensorConfigLua);
RtttNetClientAPI.RtttNetClient.SendCommand(luaCommand);

%% SAR Scan Configuration
% Aperture dimensions
horizontalApertureSize_mm = 250;
verticalApertureSize_mm   = 250;

% Number of scan positions
numHorizontalSteps = 250;
numVerticalSteps   = 125;

% Step size
horizontalStepSize_mm = horizontalApertureSize_mm / numHorizontalSteps;
verticalStepSize_mm   = verticalApertureSize_mm / numVerticalSteps;

% Stage motion settings
initialOffset_mm = 50;      % Initial offset in X and Y
samplingSpeed    = 20000;   % Jog speed

%% Output Folder for Raw ADC Data
% Create a folder based on the SAR scan configuration
binFolderName = sprintf('aperture_%dby%d_Step_%dby%d', ...
    verticalApertureSize_mm, horizontalApertureSize_mm, ...
    numVerticalSteps, numHorizontalSteps);

binFolderPath = fullfile(mainDir, 'radar_data', 'binFiles_NotParsed', binFolderName);

if ~exist(binFolderPath, 'dir')
    mkdir(binFolderPath);
    fprintf('Created bin folder: %s\n', binFolderPath);
else
    fprintf('Bin folder already exists: %s\n', binFolderPath);
end

%% Data Collection Mode
% 1 = rectangular aperture scan (2D)
% 0 = linear aperture scan (1D)
dataCollectionScenario = 1;

%% SAR Data Collection
switch dataCollectionScenario

    case 1
        %% Rectangular Aperture Scan (2D)
        moveInitial_AB(samplingSpeed, initialOffset_mm, s);
        motionTime_sec = waitTime_cal(samplingSpeed, initialOffset_mm);
        pause(motionTime_sec + 1);

        currentHorizontalStep_mm = horizontalStepSize_mm;

        for nV = 1:numVerticalSteps
            for nH = 1:numHorizontalSteps

                % Build output filename for current scan position
                fileName = fullfile(binFolderPath, ...
                    sprintf('adcData_V%dH%d.bin', nV, nH));

                % Escape backslashes for mmStudio command string
                fileNameCmd = strrep(fileName, '\', '\\');

                % Start capture and trigger radar frame
                RtttNetClientAPI.RtttNetClient.SendCommand( ...
                    ['ar1.CaptureCardConfig_StartRecord("' fileNameCmd '", 1)']);
                RtttNetClientAPI.RtttNetClient.SendCommand('ar1.StartFrame()');

                pause(3);  % Allow time for data capture

                % Move along horizontal axis unless at end of row
                if nH ~= numHorizontalSteps
                    move_A(samplingSpeed, currentHorizontalStep_mm, s);
                    motionTime_sec = waitTime_cal(samplingSpeed, abs(currentHorizontalStep_mm));
                    pause(motionTime_sec + 0.5);
                end
            end

            % Move to next row and reverse horizontal direction (serpentine scan)
            if nV ~= numVerticalSteps
                move_B(samplingSpeed, verticalStepSize_mm, s);
                motionTime_sec = waitTime_cal(samplingSpeed, verticalStepSize_mm);
                pause(motionTime_sec + 0.5);

                currentHorizontalStep_mm = -currentHorizontalStep_mm;
            end
        end

    case 0
        %% Linear Aperture Scan (1D)
        moveInitial_AB(samplingSpeed, initialOffset_mm, s);
        motionTime_sec = waitTime_cal(samplingSpeed, initialOffset_mm);
        pause(motionTime_sec + 1);

        nV = 1;  % Single row index for linear scan

        for nH = 1:numHorizontalSteps

            % Build output filename for current scan position
            fileName = fullfile(binFolderPath, ...
                sprintf('adcData_V%dH%d.bin', nV, nH));

            % Escape backslashes for mmStudio command string
            fileNameCmd = strrep(fileName, '\', '\\');

            % Start capture and trigger radar frame
            RtttNetClientAPI.RtttNetClient.SendCommand( ...
                ['ar1.CaptureCardConfig_StartRecord("' fileNameCmd '", 1)']);
            RtttNetClientAPI.RtttNetClient.SendCommand('ar1.StartFrame()');

            pause(3);  % Allow time for data capture

            % Move to next horizontal position
            if nH ~= numHorizontalSteps
                move_A(samplingSpeed, horizontalStepSize_mm, s);
                motionTime_sec = waitTime_cal(samplingSpeed, horizontalStepSize_mm);
                pause(motionTime_sec + 0.5);
            end
        end

    otherwise
        error('Invalid dataCollectionScenario. Use 1 for rectangular scan or 0 for linear scan.');
end

%% Return Stage to Home Position
pause(1);
home_stage;