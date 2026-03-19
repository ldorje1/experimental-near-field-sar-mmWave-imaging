%% generate_sar_image.m
% Near-field SAR / mmWave image reconstruction from experimental raw data.
%
% This script is intentionally limited to image generation only.
% It does not include any attack, optimization, or adversarial imaging code.
%
% Expected folder structure:
%   project_root/
%   ├── generate_sar_image.m
%   ├── raw_sar_data/
%   │   ├── knife.mat
%   │   ├── plier.mat
%   │   └── ...
%   └── figures/
%
% Each .mat file must contain:
%   adcDataCube   -> [Nsamp x M x N] complex/raw SAR data cube

clc; clear; close all;

%% User settings
cfg.dataDir      = fullfile(pwd, 'raw_sar_data');
cfg.outputDir    = fullfile(pwd, 'figures');

cfg.dataset      = 'knife';   % Options:
% 'knife', 'plier', 'scissor', 'screw_driver', 'sharp_paint_speader',
% 'dragger', 'wrench', 'gun', 'rifle', 'butcher_knife'

cfg.algorithm    = 'MFA';     % Options: 'MFA', 'RMA', 'BPA', 'LIA'

cfg.nFFTtime     = 1024;      % Range FFT size
cfg.nFFTspace    = 1024;      % Spatial FFT size (used by MFA/RMA)
cfg.bbox         = [-200 200 -200 200];   % [xmin xmax ymin ymax] in mm

cfg.bpaImageSize = [50 50];   % [A B] image grid for BPA/LIA
cfg.saveImage    = false;     % true to save reconstructed image
cfg.imageFormat  = 'png';     % 'png', 'pdf', etc.

%% Load dataset metadata
meta = getDatasetConfig(cfg.dataset);

%% Load SAR raw data
dataFile = fullfile(cfg.dataDir, sprintf('%s.mat', cfg.dataset));
if ~exist(dataFile, 'file')
    error('Dataset file not found: %s', dataFile);
end

S = load(dataFile);
if ~isfield(S, 'adcDataCube')
    error('The file "%s" does not contain variable "adcDataCube".', dataFile);
end

sarRawData = S.adcDataCube;   % [Nsamp x M x N]

%% Reconstruct SAR image
[imgAbs, imgComplex, params] = reconstructSARImage(sarRawData, cfg, meta);

% Normalize for display
imgDisplay = imgAbs / (max(imgAbs(:)) + eps);

%% Display result
figure('Color', 'w');
imagesc(imgDisplay);
axis image off;
set(gca, 'YDir', 'normal');
colormap gray;
colorbar;
title(sprintf('%s Reconstruction: %s', upper(cfg.algorithm), strrep(cfg.dataset, '_', ' ')));

%% Save image
if cfg.saveImage
    if ~exist(cfg.outputDir, 'dir')
        mkdir(cfg.outputDir);
    end

    outFile = fullfile(cfg.outputDir, ...
        sprintf('%s_%s.%s', lower(cfg.algorithm), lower(cfg.dataset), lower(cfg.imageFormat)));

    exportgraphics(gcf, outFile, 'Resolution', 300);
    fprintf('Saved image: %s\n', outFile);
end

%% Print summary
fprintf('\nReconstruction complete.\n');
fprintf('Dataset   : %s\n', cfg.dataset);
fprintf('Algorithm : %s\n', upper(cfg.algorithm));
fprintf('Data size : [%d x %d x %d]\n', size(sarRawData,1), size(sarRawData,2), size(sarRawData,3));
fprintf('Image size: [%d x %d]\n\n', size(imgAbs,1), size(imgAbs,2));

%% ========================================================================
%% Local functions
%% ========================================================================

function meta = getDatasetConfig(datasetName)
% Returns scan geometry and sampling settings for each dataset.

    switch lower(string(datasetName))
        case "knife"
            meta = struct('dx', 1, 'dy', 1, 'z0', 185, 'FS', 5000e3);

        case "plier"
            meta = struct('dx', 1, 'dy', 2, 'z0', 210, 'FS', 5000e3);

        case "scissor"
            meta = struct('dx', 1, 'dy', 2, 'z0', 215, 'FS', 5000e3);

        case "screw_driver"
            meta = struct('dx', 1, 'dy', 2, 'z0', 230, 'FS', 5000e3);

        case "sharp_paint_speader"
            meta = struct('dx', 1, 'dy', 2, 'z0', 180, 'FS', 5000e3);

        case "dragger"
            meta = struct('dx', 1, 'dy', 2, 'z0', 195, 'FS', 5000e3);

        case "wrench"
            meta = struct('dx', 1, 'dy', 1, 'z0', 170, 'FS', 9121e3);

        case "gun"
            meta = struct('dx', 1, 'dy', 1, 'z0', 185, 'FS', 9121e3);

        case "rifle"
            meta = struct('dx', 1, 'dy', 1, 'z0', 185, 'FS', 9121e3);

        case "butcher_knife"
            meta = struct('dx', 1, 'dy', 2, 'z0', 210, 'FS', 5000e3);

        otherwise
            error('Unknown dataset: %s', datasetName);
    end
end

function [imgAbs, imgComplex, params] = reconstructSARImage(sarRawData, cfg, meta)
% Main SAR reconstruction wrapper.

    c0 = 299792458;       % speed of light (m/s)
    F0 = 77e9;            % start frequency (Hz)
    K0 = 70.295e12;       % chirp slope (Hz/s)
    tI = 4.5225e-10;      % instrument delay (s)

    [Nsamp, M, N] = size(sarRawData);

    params = struct();
    params.F0        = F0;
    params.Nsamp     = Nsamp;
    params.M         = M;
    params.N         = N;
    params.dx        = meta.dx;
    params.dy        = meta.dy;
    params.bbox      = cfg.bbox;
    params.nFFTtime  = cfg.nFFTtime;
    params.nFFTspace = cfg.nFFTspace;
    params.sar_algo  = upper(cfg.algorithm);

    switch upper(cfg.algorithm)

        case 'MFA'
            k0_range_bin = round(K0 / meta.FS * (2 * meta.z0 * 1e-3 / c0 + tI) * cfg.nFFTtime);

            rawDataFFT = fft(sarRawData, cfg.nFFTtime, 1);
            sarData = squeeze(rawDataFFT(k0_range_bin + 1, :, :));
            sarData = applySerpentineCorrection(sarData);

            params.z0 = meta.z0;                  % mm
            params.k0_range_bin = k0_range_bin;

            [~, ~, imgAbs, imgComplex] = reconstructMFA(sarData, params);

        case 'RMA'
            Echo = permute(sarRawData, [3, 2, 1]);     % [N x M x Nsamp]
            numSamples = size(Echo, 3);

            rawDataFFT = fft(Echo, numSamples, 3);
            energyProfile = squeeze(sum(sum(abs(rawDataFFT).^2, 1), 2));

            [~, k0_range_bin] = max(energyProfile);
            k0_range_bin = overrideRangeBin(cfg.dataset, k0_range_bin, 'RMA');

            sarData = squeeze(rawDataFFT(:, :, k0_range_bin)).';
            sarData = applySerpentineCorrection(sarData);

            z0_rma_m = (c0/2) * (((k0_range_bin - 1) / (K0 * (1/meta.FS) * numSamples)) - tI);

            params.z0 = z0_rma_m;                 % meters for RMA phase term
            params.nFFTtime = numSamples;
            params.k0_range_bin = k0_range_bin;

            [~, ~, imgAbs, imgComplex] = reconstructRMA(sarData, params);

        case 'BPA'
            k0_range_bin = round(K0 * (1/meta.FS) * (2 * meta.z0 * 1e-3 / c0 + tI) * cfg.nFFTtime);
            k0_range_bin = overrideRangeBin(cfg.dataset, k0_range_bin, 'BPA');

            rawDataFFT = fft(sarRawData, cfg.nFFTtime, 1);
            sarData = squeeze(rawDataFFT(k0_range_bin + 1, :, :));
            sarData = applySerpentineCorrection(sarData);

            params.z0 = meta.z0;                  % mm
            params.k0_range_bin = k0_range_bin;
            params.A_bpa = cfg.bpaImageSize(1);
            params.B_bpa = cfg.bpaImageSize(2);

            H = buildBPAKernel(params);
            [~, ~, imgAbs, imgComplex] = reconstructBPA(sarData, params, H);

        case 'LIA'
            k0_range_bin = round(K0 * (1/meta.FS) * (2 * meta.z0 * 1e-3 / c0 + tI) * cfg.nFFTtime);
            k0_range_bin = overrideRangeBin(cfg.dataset, k0_range_bin, 'LIA');

            rawDataFFT = fft(sarRawData, cfg.nFFTtime, 1);
            sarData = squeeze(rawDataFFT(k0_range_bin + 1, :, :));
            sarData = applySerpentineCorrection(sarData);

            params.z0 = meta.z0;                  % mm
            params.k0_range_bin = k0_range_bin;
            params.A_bpa = cfg.bpaImageSize(1);
            params.B_bpa = cfg.bpaImageSize(2);

            H = buildBPAKernel(params);

            NM = numel(sarData);
            kk = min(40000, NM);
            rng(1000);
            params.py = sort(randperm(NM, kk));

            [~, ~, imgAbs, imgComplex] = reconstructLIA(sarData, params, H);

        otherwise
            error('Invalid algorithm: %s', cfg.algorithm);
    end
end

function sarData = applySerpentineCorrection(sarData)
% Flips every other row to correct serpentine stage scanning.
    for ii = 2:2:size(sarData, 1)
        sarData(ii, :) = fliplr(sarData(ii, :));
    end
end

function kbin = overrideRangeBin(datasetName, kbinDefault, algorithmName)
% Manual range-bin overrides for specific datasets.

    kbin = kbinDefault;
    label = lower(string(datasetName));
    algo  = upper(string(algorithmName));

    switch algo
        case 'RMA'
            switch label
                case {"screw_driver", "gun", "rifle"}
                    kbin = 8;
                case "wrench"
                    kbin = 7;
            end

        case {'BPA', 'LIA'}
            switch label
                case "gun"
                    kbin = 14;
                case "rifle"
                    kbin = 13;
            end
    end
end

function matchedFilter = buildMatchedFilter(params)
% 2D matched filter for MFA.

    c0 = 299792458;
    x = params.dx * (-(params.nFFTspace - 1)/2 : (params.nFFTspace - 1)/2) * 1e-3;
    y = (params.dy * (-(params.nFFTspace - 1)/2 : (params.nFFTspace - 1)/2) * 1e-3).';
    z0_m = params.z0 * 1e-3;
    k = 2 * pi * params.F0 / c0;

    matchedFilter = exp(-1i * 2 * k * sqrt(x.^2 + y.^2 + z0_m^2));
end

function [xRangeT, yRangeT, imgAbs, imgComplex] = reconstructMFA(sarData, params)
% Matched Filter Algorithm (MFA).

    matchedFilter = buildMatchedFilter(params);

    [yPointM, xPointM] = size(sarData);
    [yPointF, xPointF] = size(matchedFilter);

    if xPointF > xPointM
        padPre = floor((xPointF - xPointM) / 2);
        padPost = ceil((xPointF - xPointM) / 2);
        sarData = cat(2, zeros(yPointM, padPre), sarData, zeros(yPointM, padPost));
        xPointM = xPointF;
    end

    if yPointF > yPointM
        padPre = floor((yPointF - yPointM) / 2);
        padPost = ceil((yPointF - yPointM) / 2);
        sarData = cat(1, zeros(padPre, xPointM), sarData, zeros(padPost, xPointM));
    end

    sarDataFFT = fft(fft(sarData, [], 2), [], 1);
    matchedFilterFFT = fft(fft(matchedFilter, [], 2), [], 1);

    img = ifft(ifft(sarDataFFT .* matchedFilterFFT, [], 2), [], 1);
    img = fftshift(img);

    [J, I] = size(img);
    xij = round(params.bbox(1:2) / params.dx - 0.5 + I/2);
    ykl = round(params.bbox(3:4) / params.dy - 0.5 + J/2);

    xij(1) = max(1, xij(1)); xij(2) = min(I, xij(2));
    ykl(1) = max(1, ykl(1)); ykl(2) = min(J, ykl(2));

    imgComplex = fliplr(img(ykl(1):ykl(2), xij(1):xij(2)));
    imgAbs = abs(imgComplex);

    xRangeT = params.bbox(1) + (0:size(imgAbs, 2) - 1) * params.dx;
    yRangeT = params.bbox(3) + (0:size(imgAbs, 1) - 1) * params.dy;
end

function [xRangeT, yRangeT, imgAbs, imgComplex] = reconstructRMA(sarData, params)
% Range Migration Algorithm (RMA).

    c0 = 299792458;
    nFFTspace = params.nFFTspace;
    z0_m = params.z0;      % meters
    dx = params.dx;
    dy = params.dy;
    bbox = params.bbox;
    F0 = params.F0;

    k = 2 * pi * F0 / c0;

    wSx = 2 * pi / (dx * 1e-3);
    kX = linspace(-wSx/2, wSx/2, nFFTspace);

    wSy = 2 * pi / (dy * 1e-3);
    kY = linspace(-wSy/2, wSy/2, nFFTspace).';

    K = sqrt((2*k).^2 - (kX.^2 + kY.^2));
    phaseFactor0 = exp(-1i * z0_m * K);

    evanescentMask = (kX.^2 + kY.^2) > (2*k)^2;
    phaseFactor0(evanescentMask) = 0;

    phaseFactor = K .* phaseFactor0;
    phaseFactor = fftshift(fftshift(phaseFactor, 1), 2);

    [yPointM, xPointM] = size(sarData);
    [yPointF, xPointF] = size(phaseFactor);

    if xPointF > xPointM
        padPre = floor((xPointF - xPointM) / 2);
        padPost = ceil((xPointF - xPointM) / 2);
        sarData = cat(2, zeros(yPointM, padPre), sarData, zeros(yPointM, padPost));
    elseif xPointM > xPointF
        padPre = floor((xPointM - xPointF) / 2);
        padPost = ceil((xPointM - xPointF) / 2);
        phaseFactor = cat(2, zeros(yPointF, padPre), phaseFactor, zeros(yPointF, padPost));
    end

    if yPointF > yPointM
        padPre = floor((yPointF - yPointM) / 2);
        padPost = ceil((yPointF - yPointM) / 2);
        sarData = cat(1, zeros(padPre, size(sarData, 2)), sarData, zeros(padPost, size(sarData, 2)));
    elseif yPointM > yPointF
        padPre = floor((yPointM - yPointF) / 2);
        padPost = ceil((yPointM - yPointF) / 2);
        phaseFactor = cat(1, zeros(padPre, size(phaseFactor, 2)), phaseFactor, zeros(padPost, size(phaseFactor, 2)));
    end

    sarDataFFT = fft(fft(sarData, [], 2), [], 1);
    img = ifft(ifft(sarDataFFT .* phaseFactor, [], 2), [], 1);

    [J, I] = size(img);
    xij = round(bbox(1:2) / dx - 0.5 + I/2);
    ykl = round(bbox(3:4) / dy - 0.5 + J/2);

    xij(1) = max(1, xij(1)); xij(2) = min(I, xij(2));
    ykl(1) = max(1, ykl(1)); ykl(2) = min(J, ykl(2));

    imgComplex = fliplr(img(ykl(1):ykl(2), xij(1):xij(2)));
    imgAbs = abs(imgComplex);

    xRangeT = bbox(1) + (0:size(imgAbs, 2) - 1) * dx;
    yRangeT = bbox(3) + (0:size(imgAbs, 1) - 1) * dy;
end

function [xRangeT, yRangeT, imgAbs, imgComplex] = reconstructBPA(sarData, params, H)
% Back-Projection Algorithm (BPA).

    A = params.A_bpa;
    B = params.B_bpa;

    y = reshape(sarData, [], 1);
    xd = H' * y;
    xdi = reshape(xd, B, A);

    imgComplex = fliplr(xdi);
    imgAbs = abs(imgComplex);

    xRangeT = params.bbox(1) + (0:size(imgAbs, 2) - 1) * params.dx;
    yRangeT = params.bbox(3) + (0:size(imgAbs, 1) - 1) * params.dy;
end

function H = buildBPAKernel(params)
% Builds the BPA propagation matrix H of size (M*N) x (A*B).

    c0 = 299792458;
    M = params.M;
    N = params.N;
    A = params.A_bpa;
    B = params.B_bpa;

    F0 = params.F0;
    z0_m = params.z0 * 1e-3;
    dxm = params.dx * 1e-3;
    dym = params.dy * 1e-3;
    bbox_m = params.bbox * 1e-3;

    k = 2 * pi * F0 / c0;
    cst = 1i * 2 * k;
    z2 = z0_m^2;

    xPixels = linspace(bbox_m(1), bbox_m(2), A);
    yPixels = linspace(bbox_m(3), bbox_m(4), B);

    Ny = M;
    Nx = N;

    NM = Ny * Nx;
    BA = A * B;

    H = complex(zeros(NM, BA));

    fprintf('Building BPA kernel H (%d x %d)... ', NM, BA);
    tic;

    for i = 1:NM
        iy = mod(i - 1, Ny);
        ix = (i - 1 - iy) / Ny;

        sx = (ix + 0.5 - Nx/2) * dxm;
        sy = (iy + 0.5 - Ny/2) * dym;

        for j = 1:BA
            jy = mod(j - 1, B);
            jx = (j - 1 - jy) / B;

            px = xPixels(jx + 1);
            py = yPixels(jy + 1);

            dist2 = (sx - px)^2 + (sy - py)^2 + z2;
            H(i, j) = exp(cst * sqrt(dist2));
        end
    end

    fprintf('done in %.3f s\n', toc);
end

function [xRangeT, yRangeT, imgAbs, imgComplex] = reconstructLIA(sarData, params, H)
% Lightweight Iterative Imaging Algorithm (LIA).

    M = params.M;
    N = params.N;
    A = params.A_bpa;
    B = params.B_bpa;
    py = params.py;

    rd_full = reshape(sarData, [], 1);
    rd = rd_full(py);

    Hp = H(py, :);
    BA = A * B;

    di = 0.01;
    G = di * (Hp' * Hp);
    xd = di * (Hp' * rd);

    for j = 1:BA
        Gj = G(:, j);
        denom = 1 + G(j, j);
        temp = Gj / denom;

        xd = xd - temp * xd(j);
        G = G - temp * G(j, :);
    end

    diagG = diag(G);
    xd = xd ./ diagG;

    xdi = fliplr(reshape(xd, B, A));

    imgComplex = xdi;
    imgAbs = abs(imgComplex);

    xRangeT = params.bbox(1) + (0:size(imgAbs, 2) - 1) * params.dx;
    yRangeT = params.bbox(3) + (0:size(imgAbs, 1) - 1) * params.dy;
end