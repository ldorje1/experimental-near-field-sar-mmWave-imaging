%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% clean version of postProcessing; Jan 2025
%
% --- changes 
%   folder name changed: adcRawData_Parsed --> sar_data



%% SAR Configuration
% Set aperture size (in mm) and number of steps for horizontal and vertical
horizontalAperatureSize_mm = 200; % Horizontal aperture size
verticalAperatureSize_mm = 200;   % Vertical aperture size
numHorizontalSteps = 200;         % Number of horizontal steps
numVerticalSteps = 200;           % Number of vertical steps

%% Directory Setup and File Cleanup
% Base folder path for post-processing data
baseFolder_path = 'C:\Users\Lhamo\Desktop\RESEARCH SPRING 2025\experimental_mmWave_imaging\post_processing';

% Bin folder name based on the SAR configuration
binFolder_name = sprintf('aperture_%dby%d_Step_%dby%d', verticalAperatureSize_mm, ...
    horizontalAperatureSize_mm, numVerticalSteps, numHorizontalSteps);

% Full path to the bin folder
binFolder_path = fullfile(baseFolder_path, 'bin_files', binFolder_name);


%% Delete Unnecessary Files
% List all .txt and .csv files in the bin folder
file_list = [dir(fullfile(binFolder_path, '*.txt')); dir(fullfile(binFolder_path, '*.csv'))];

% Delete each file in the list
for i = 1:numel(file_list)
    file_to_delete = fullfile(binFolder_path, file_list(i).name); % Get full file path
    delete(file_to_delete); % Delete the file
    disp(['Deleted: ' file_to_delete]); % Display the deleted file's path
end

%% Interpolate Missing Files
% Check for missing bin files and fill the gaps by copying from previous or subsequent files

allBinFilesExist = true; % Assume all files exist initially

for nV = 1:numVerticalSteps
    for nH = 1:numHorizontalSteps
        % Define the current bin file name and path
        binFile_name = sprintf('adcData_V%dH%d_Raw_0.bin', nV, nH);
        binFile_path = fullfile(binFolder_path, binFile_name);
        
        % Check if the current bin file exists
        if exist(binFile_path, 'file') ~= 2
            fprintf('Bin file not found: %s\n', binFile_name); % Print the missing file name
            allBinFilesExist = false; % Update the flag if any file is missing
            
            if nH > 1
                % If the missing file is not the first horizontal step, copy the previous file
                previous_binFile_name = sprintf('adcData_V%dH%d_Raw_0.bin', nV, nH - 1);
                previous_binFile_path = fullfile(binFolder_path, previous_binFile_name);
                
                if exist(previous_binFile_path, 'file') == 2
                    copyfile(previous_binFile_path, binFile_path); % Copy the previous file
                    fprintf('Copied and renamed: %s to %s\n', previous_binFile_name, binFile_name);
                else
                    fprintf('Previous bin file not found: %s. Skipping copy.\n', previous_binFile_name);
                end
            else
                % If the missing file is the first horizontal step, search for the next available file
                next_binFile_found = false;
                for nextH = nH+1:numHorizontalSteps
                    next_binFile_name = sprintf('adcData_V%dH%d_Raw_0.bin', nV, nextH);
                    next_binFile_path = fullfile(binFolder_path, next_binFile_name);
                    
                    if exist(next_binFile_path, 'file') == 2
                        copyfile(next_binFile_path, binFile_path); % Copy the next file
                        fprintf('Copied and renamed: %s to %s\n', next_binFile_name, binFile_name);
                        next_binFile_found = true;
                        break; % Exit the loop once a valid next file is found
                    end
                end
                
                if ~next_binFile_found
                    fprintf('No subsequent bin files found to copy for: %s. Skipping.\n', binFile_name);
                end
            end
        end
    end
end

% Final check to confirm that all bin files exist
if allBinFilesExist
    fprintf('All bin files exist\n');
end

%% Bin File Size Equalizer
% Ensure all bin files are of the same size (2048 bytes). If not, delete the file
% and copy the previous one to maintain consistency.

for nV = 1:numVerticalSteps
    for nH = 1:numHorizontalSteps
        % Define current file name and path
        binFile_name = sprintf('adcData_V%dH%d_Raw_0.bin', nV, nH);
        binFile_path = fullfile(baseFolder_path, 'bin_files', binFolder_name, binFile_name);
        
        % Open the file and read its contents
        fid = fopen(binFile_path, 'r');
        adcData = fread(fid, 'int16');
        fclose(fid);
        
        % Get the file size
        fileSize = numel(adcData);
        
        % Check if the file size is not 2048

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % WITH ADC SAMPLING 256 --> FILESIZE -->2048
        % WITH ADC SAMPLING 512 --> FILESIZE -->4096

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        %if fileSize ~= 2048
        if fileSize ~= 4096
            fprintf('Deleting file: %s (Size: %d)\n', binFile_name, fileSize);
            delete(binFile_path); % Delete the file if size mismatch
            
            % Attempt to copy the previous file, if available
            if nH > 1
                previousFile_name = sprintf('adcData_V%dH%d_Raw_0.bin', nV, nH - 1);
                previousFile_path = fullfile(baseFolder_path, 'bin_files', binFolder_name, previousFile_name);
                
                if exist(previousFile_path, 'file')
                    % Copy and rename the previous file
                    copyfile(previousFile_path, binFile_path);
                    fprintf('Copied file: %s to %s\n', previousFile_name, binFile_name);
                else
                    fprintf('Previous file not found: %s\n', previousFile_name);
                end
            else
                fprintf('No previous file to copy from for: %s\n', binFile_name);
            end
        end
    end
end

%% Data Parsing
% Parse ADC raw data from the bin files into a 3D data cube.

rx = 1; % Data from receiver 1
adcDataCube = zeros(numVerticalSteps, numHorizontalSteps, 512); % Initialize the data cube

% Process the rectangular aperture data
for nV = 1:numVerticalSteps
    for nH = 1:numHorizontalSteps
        % Define the current bin file name and path
        binFile_name = sprintf('adcData_V%dH%d_Raw_0.bin', nV, nH);
        binFile_path = fullfile(baseFolder_path, 'bin_files', binFolder_name, binFile_name);
        
        % Print the file name for tracking purposes
        fprintf('Processing file: %s\n', binFile_name);
        
        % Read the data using the DCA1000 reader function
        adcData = readDCA1000(binFile_path);
        
        % Extract data for the specified receiver and store it in the data cube
        adcDataCube(nV, nH, :) = adcData(rx, :);
    end
end

%% Simulating SAR Aperture via Data Reindexing
% Reindex the data cube to simulate sequential sensor movement in a rectangular aperture.

adcData_temp = zeros(size(adcDataCube)); % Initialize temporary data cube

for slice = 1:size(adcDataCube, 3)
    temp_slice = adcDataCube(:, :, slice); % Extract the current slice

    % Handle reindexing for even-sized matrices
    if mod(size(adcDataCube, 1), 2) == 0
        for i = 1:size(temp_slice, 1) % Iterate through rows
            if mod(i, 2) ~= 0 
                row = flip(temp_slice(size(temp_slice, 1) + 1 - i, :)); % Flip odd rows
                adcData_temp(i, :, slice) = row; 
            else
                adcData_temp(i, :, slice) = temp_slice(size(temp_slice, 1) + 1 - i, :);
            end 
        end
    % Handle reindexing for odd-sized matrices
    elseif mod(size(adcDataCube, 1), 2) ~= 0
        for i = 1:size(temp_slice, 1) % Iterate through rows
            if mod(i, 2) == 0 
                row = flip(temp_slice(size(temp_slice, 1) + 1 - i, :)); % Flip even rows
                adcData_temp(i, :, slice) = row; 
            else
                adcData_temp(i, :, slice) = temp_slice(size(temp_slice, 1) + 1 - i, :);
            end 
        end
    end
end 

% Re-organize the parsed data structure
% Yanik's data structure: nSample × nVertical × nHorizontal
% Reshape from VxHxS to SxVxH
adcDataCube = permute(adcDataCube, [3, 1, 2]);
