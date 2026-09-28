%% generate_wave_inputs.m
% Generate JONSWAP and finite-depth TMA wave spectra together with
% wave-elevation time series for SIMA/SIMO time-domain analysis.
%
% Three wave inputs are produced for each environmental case:
%   1) JONSWAP reference spectrum (JS)
%   2) Direct finite-depth corrected spectrum (FD-DC)
%   3) Hs- and Tp-matched finite-depth spectrum (FD-HM)
%
% The three time series in a given case use the same frequency grid and
% phase vector. Only the spectral density differs between them.

clear; clc; close all;

%% User settings
% Run all rows in CaseTable, or use SingleCase only.
runMode = 'case_table';

% Environmental cases.
CaseID = {'EC1'; 'EC2'; 'EC3'; 'EC4'; 'EC5'};
Hs_m   = [1.0;  1.0;  1.0;  1.0;  1.0];
Tp_s   = [5.5;  5.5;  5.5;  3.5;  7.5];
h_m    = [8.0; 15.0; 21.0;  8.0;  8.0];
CaseTable = table(CaseID, Hs_m, Tp_s, h_m);

% Single-case settings.
SingleCase.CaseID = 'CASE_SINGLE';
SingleCase.Hs_m   = 1.0;
SingleCase.Tp_s   = 5.5;
SingleCase.h_m    = 8.0;

% Spectral and physical parameters.
gamma = 3.3;       % JONSWAP peak enhancement factor [-]
g     = 9.81;      % Gravity [m/s^2]

% Spectrum frequency grid.
f_min_calc = 0.02;   % Minimum frequency [Hz]
f_max_calc = 2.00;   % Maximum frequency [Hz]
df         = 0.001;  % Frequency interval [Hz]

% Plot range.
f_min_plot = 0.02;   % Minimum plotting frequency [Hz]
f_max_plot = 0.60;   % Maximum plotting frequency [Hz]

% Finite-depth correction:
%   'exact'     : finite-depth correction based on dispersion relation
%   'piecewise' : empirical TMA correction function
tmaOption = 'exact';

% Match FD-HM to both target Hs and Tp when true.
matchFinalTMA_Tp = true;

%% Time-series settings
generateTimeSeries = true;

timeSeriesDuration_s = 3600.0;   % Total time length [s]
timeSeries_dt_s       = 0.01;    % Time step [s]

% Common phase vector for all three spectra in each case.
timeSeriesPhaseMode   = 'deterministic_lcg';
timeSeriesPhaseSeed   = 1;
timeSeriesPhaseOffset_rad = 0.0;

removeTimeSeriesMean = true;

% Rescale each finite record so that 4*std(eta) matches its spectrum Hm0.
forceTimeSeriesHm0ToSpectrum = true;

%% Output settings
exportCSV = true;
exportExcel = false;
exportTimeSeriesExcel = false;
exportMAT = false;
exportSIMA_ASC = true;
makeFigures = false;
showPreviewInCommandWindow = false;
openOutputRootAfterRun = true;

% Output folder created beside this script.
outputRootName = 'wave_input_output';

%% Resolve paths and case list
scriptFullPathNoExt = mfilename('fullpath');
if isempty(scriptFullPathNoExt)
    scriptDir = pwd;
    scriptName = 'generate_wave_inputs.m';
    sourceScript = '';
else
    [scriptDir, scriptBase, ~] = fileparts(scriptFullPathNoExt);
    scriptName = [scriptBase '.m'];
    sourceScript = [scriptFullPathNoExt '.m'];
end

outRoot = fullfile(scriptDir, outputRootName);
ensureFolder(outRoot);

if ~isempty(sourceScript) && exist(sourceScript, 'file')
    copyfile(sourceScript, fullfile(outRoot, scriptName));
end

switch lower(strtrim(runMode))
    case 'case_table'
        casesToRun = CaseTable;
    case 'single_case'
        casesToRun = table({SingleCase.CaseID}, SingleCase.Hs_m, SingleCase.Tp_s, SingleCase.h_m, ...
            'VariableNames', {'CaseID', 'Hs_m', 'Tp_s', 'h_m'});
    otherwise
        error('Unknown runMode. Use case_table or single_case.');
end

%% Run cases
AllCaseSummary = table();

for iCase = 1:height(casesToRun)
    caseInput.CaseID = char(casesToRun.CaseID{iCase});
    caseInput.Hs     = casesToRun.Hs_m(iCase);
    caseInput.Tp     = casesToRun.Tp_s(iCase);
    caseInput.h      = casesToRun.h_m(iCase);
    caseInput.gamma  = gamma;
    caseInput.g      = g;
    caseInput.f_min_calc = f_min_calc;
    caseInput.f_max_calc = f_max_calc;
    caseInput.df = df;
    caseInput.f_min_plot = f_min_plot;
    caseInput.f_max_plot = f_max_plot;
    caseInput.tmaOption = tmaOption;
    caseInput.matchFinalTMA_Tp = matchFinalTMA_Tp;
    caseInput.generateTimeSeries = generateTimeSeries;
    caseInput.timeSeriesDuration_s = timeSeriesDuration_s;
    caseInput.timeSeries_dt_s = timeSeries_dt_s;
    caseInput.timeSeriesPhaseMode = timeSeriesPhaseMode;
    caseInput.timeSeriesPhaseSeed = timeSeriesPhaseSeed;
    caseInput.timeSeriesPhaseOffset_rad = timeSeriesPhaseOffset_rad;
    caseInput.removeTimeSeriesMean = removeTimeSeriesMean;
    caseInput.forceTimeSeriesHm0ToSpectrum = forceTimeSeriesHm0ToSpectrum;
    caseInput.exportCSV = exportCSV;
    caseInput.exportExcel = exportExcel;
    caseInput.exportTimeSeriesExcel = exportTimeSeriesExcel;
    caseInput.exportMAT = exportMAT;
    caseInput.exportSIMA_ASC = exportSIMA_ASC;
    caseInput.makeFigures = makeFigures;
    caseInput.showPreviewInCommandWindow = showPreviewInCommandWindow;

    fprintf('\n============================================================\n');
    fprintf('Running case %d/%d: %s, Hs = %.3g m, Tp = %.3g s, h = %.3g m\n', ...
        iCase, height(casesToRun), caseInput.CaseID, caseInput.Hs, caseInput.Tp, caseInput.h);
    fprintf('============================================================\n');

    caseSummary = runOneWaveSpectrumCase(caseInput, outRoot, scriptName, sourceScript);

    if isempty(AllCaseSummary)
        AllCaseSummary = caseSummary;
    else
        AllCaseSummary = [AllCaseSummary; caseSummary]; %#ok<AGROW>
    end
end

%% Export case index
summaryCSV = fullfile(outRoot, '00_ALL_CASE_SUMMARY.csv');
summaryXLSX = fullfile(outRoot, '00_ALL_CASE_SUMMARY.xlsx');
readmePath = fullfile(outRoot, '00_README_OUTPUT_STRUCTURE.txt');

if exportCSV
    writetable(AllCaseSummary, summaryCSV);
end

if exportExcel
    if exist(summaryXLSX, 'file'); delete(summaryXLSX); end
    writetable(AllCaseSummary, summaryXLSX, 'Sheet', 'All_case_summary');
end

writeRootReadme(readmePath, outRoot, timeSeriesDuration_s, timeSeries_dt_s, timeSeriesPhaseMode, timeSeriesPhaseSeed);

fprintf('\n========== ALL CASES FINISHED ==========\n');
fprintf('Output root folder:\n%s\n', outRoot);
fprintf('Root summary:\n%s\n', summaryCSV);

if openOutputRootAfterRun
    openFolder(outRoot);
end

%% Local functions

function CaseSummary = runOneWaveSpectrumCase(inp, outRoot, scriptName, sourceScript)
    spectrumNames = {'JONSWAP_reference'; 'TMA_direct_FD_DC'; 'TMA_final_FD_HM'};

    caseName = makeCaseName(inp.CaseID, inp.Hs, inp.Tp, inp.h, inp.tmaOption);

    caseDir = fullfile(outRoot, caseName);
    spectraDir = fullfile(caseDir, 'spectra');
    timeSeriesDir = fullfile(caseDir, 'wave_elevation');
    simaDir = fullfile(caseDir, 'sima_asc');
    figureDir = '';
    ensureFolder(caseDir);
    ensureFolder(spectraDir);
    ensureFolder(timeSeriesDir);
    ensureFolder(simaDir);
    if inp.makeFigures
        figureDir = fullfile(caseDir, 'figures');
        ensureFolder(figureDir);
    end

    if ~isempty(sourceScript) && exist(sourceScript, 'file')
        copyfile(sourceScript, fullfile(caseDir, scriptName));
    end

    %% Frequency vector
    Hs = inp.Hs;
    Tp = inp.Tp;
    h = inp.h;
    gamma = inp.gamma;
    g = inp.g;
    fp_target = 1 / Tp;
    m0_target = Hs^2 / 16;

    f = (inp.f_min_calc:inp.df:inp.f_max_calc).';
    f = unique([f; fp_target]);
    f = sort(f, 'ascend');
    omega = 2*pi*f;
    Period_s = 1 ./ f;

    %% Finite-depth correction
    k = waveNumberFiniteDepth(omega, h, g);
    kh = k * h;
    Phi = finiteDepthCorrection(omega, kh, h, g, inp.tmaOption);

    %% 1. JONSWAP reference
    S_JS_shape = jonswapShape(f, fp_target, gamma, g);
    S_JS_Hz = normalizeSpectrumToM0(f, S_JS_shape, m0_target);

    %% 2. TMA direct FD-DC
    S_TMA_direct_Hz = S_JS_Hz .* Phi;

    %% 3. TMA final FD-HM
    if inp.matchFinalTMA_Tp
        fp_base_TMA = findBaseFpForFinalTMA_Tp(f, Phi, gamma, g, fp_target, Tp, m0_target);
    else
        fp_base_TMA = fp_target;
    end
    Tp_base_TMA = 1 / fp_base_TMA;

    S_TMA_base_shape = jonswapShape(f, fp_base_TMA, gamma, g);
    S_TMA_base_Hz = normalizeSpectrumToM0(f, S_TMA_base_shape, m0_target);
    S_TMA_uncalibrated_Hz = S_TMA_base_Hz .* Phi;
    m0_TMA_uncalibrated = trapz(f, S_TMA_uncalibrated_Hz);
    if m0_TMA_uncalibrated <= 0
        error('TMA uncalibrated spectrum has zero or negative area.');
    end
    C_HM = m0_target / m0_TMA_uncalibrated;
    S_TMA_final_Hz = C_HM * S_TMA_uncalibrated_Hz;

    %% Convert to S(omega)
    S_JS_rad = S_JS_Hz / (2*pi);
    S_TMA_direct_rad = S_TMA_direct_Hz / (2*pi);
    S_TMA_final_rad = S_TMA_final_Hz / (2*pi);

    S_matrix_Hz = [S_JS_Hz, S_TMA_direct_Hz, S_TMA_final_Hz];
    S_matrix_rad = [S_JS_rad, S_TMA_direct_rad, S_TMA_final_rad];

    %% Spectral parameters
    param_JS = spectralParameters(f, S_JS_Hz);
    param_TMA_direct = spectralParameters(f, S_TMA_direct_Hz);
    param_TMA_final = spectralParameters(f, S_TMA_final_Hz);

    FullCurveFrequencyTable = table( ...
        f, omega, Period_s, k, kh, Phi, ...
        S_JS_Hz, S_TMA_direct_Hz, S_TMA_final_Hz, ...
        S_JS_rad, S_TMA_direct_rad, S_TMA_final_rad, ...
        'VariableNames', { ...
        'f_Hz', 'omega_rad_s', 'Period_s', 'k_1_m', 'kh', 'Phi_TMA', ...
        'S_JONSWAP_reference_m2_Hz', ...
        'S_TMA_direct_FD_DC_m2_Hz', ...
        'S_TMA_final_FD_HM_m2_Hz', ...
        'S_JONSWAP_reference_m2_s_rad', ...
        'S_TMA_direct_FD_DC_m2_s_rad', ...
        'S_TMA_final_FD_HM_m2_s_rad'});

    [Period_sorted, idxT] = sort(Period_s, 'ascend');
    FullCurvePeriodTable = FullCurveFrequencyTable(idxT, :);
    FullCurvePeriodTable.Period_s = Period_sorted;

    InputTable = table( ...
        {inp.CaseID}, Hs, Tp, h, gamma, ...
        inp.f_min_calc, inp.f_max_calc, inp.df, ...
        inp.f_min_plot, inp.f_max_plot, ...
        {inp.tmaOption}, inp.matchFinalTMA_Tp, ...
        fp_target, fp_base_TMA, Tp_base_TMA, C_HM, ...
        inp.timeSeriesDuration_s, inp.timeSeries_dt_s, ...
        {inp.timeSeriesPhaseMode}, inp.timeSeriesPhaseSeed, ...
        inp.removeTimeSeriesMean, inp.forceTimeSeriesHm0ToSpectrum, ...
        'VariableNames', { ...
        'CaseID', 'Target_Hs_m', 'Target_Tp_s', 'WaterDepth_m', 'Gamma', ...
        'f_min_calc_Hz', 'f_max_calc_Hz', 'df_Hz', ...
        'f_min_plot_Hz', 'f_max_plot_Hz', ...
        'TMA_option', 'Match_final_TMA_Tp', ...
        'Target_fp_Hz', 'Internal_base_fp_for_TMA_Hz', ...
        'Internal_base_Tp_for_TMA_s', 'TMA_final_Hs_scale_factor', ...
        'TimeSeries_duration_s', 'TimeSeries_dt_s', ...
        'TimeSeries_phase_mode', 'TimeSeries_phase_seed', ...
        'Remove_time_series_mean', 'Force_time_series_Hm0_to_spectrum'});

    SummaryTable = table( ...
        spectrumNames, ...
        [param_JS.Hm0; param_TMA_direct.Hm0; param_TMA_final.Hm0], ...
        [param_JS.Tp_spec; param_TMA_direct.Tp_spec; param_TMA_final.Tp_spec], ...
        [param_JS.fp_spec; param_TMA_direct.fp_spec; param_TMA_final.fp_spec], ...
        [param_JS.m0; param_TMA_direct.m0; param_TMA_final.m0], ...
        [param_JS.m1; param_TMA_direct.m1; param_TMA_final.m1], ...
        [param_JS.m2; param_TMA_direct.m2; param_TMA_final.m2], ...
        [param_JS.Tm01; param_TMA_direct.Tm01; param_TMA_final.Tm01], ...
        [param_JS.Tm02; param_TMA_direct.Tm02; param_TMA_final.Tm02], ...
        [param_JS.Hm0/Hs; param_TMA_direct.Hm0/Hs; param_TMA_final.Hm0/Hs], ...
        [(1-param_JS.Hm0/Hs)*100; (1-param_TMA_direct.Hm0/Hs)*100; (1-param_TMA_final.Hm0/Hs)*100], ...
        [param_JS.Tp_spec/Tp; param_TMA_direct.Tp_spec/Tp; param_TMA_final.Tp_spec/Tp], ...
        'VariableNames', { ...
        'SpectrumType', 'Hm0_m', 'Tp_spec_s', 'fp_spec_Hz', ...
        'm0', 'm1', 'm2', 'Tm01_s', 'Tm02_s', ...
        'Hm0_over_target_Hs', 'Hs_reduction_percent_vs_target', ...
        'Tp_spec_over_target_Tp'});

    ReductionTable = table( ...
        param_TMA_direct.Hm0, param_TMA_direct.Hm0/Hs, (1-param_TMA_direct.Hm0/Hs)*100, ...
        param_TMA_direct.m0, param_TMA_direct.m0/m0_target, (1-param_TMA_direct.m0/m0_target)*100, ...
        param_TMA_direct.Tp_spec, param_TMA_direct.Tp_spec/Tp, ...
        'VariableNames', { ...
        'TMA_direct_Hm0_m', 'TMA_direct_Hm0_over_target_Hs', ...
        'TMA_direct_Hs_reduction_percent', ...
        'TMA_direct_m0', 'TMA_direct_m0_over_target_m0', ...
        'TMA_direct_energy_reduction_percent', ...
        'TMA_direct_Tp_spec_s', 'TMA_direct_Tp_spec_over_target_Tp'});

    MatchingTable = table( ...
        fp_target, fp_base_TMA, Tp, Tp_base_TMA, ...
        param_TMA_final.Hm0, param_TMA_final.Hm0 - Hs, ...
        param_TMA_final.Tp_spec, param_TMA_final.Tp_spec - Tp, C_HM, ...
        'VariableNames', { ...
        'Target_fp_Hz', 'Internal_base_fp_for_TMA_Hz', ...
        'Target_Tp_s', 'Internal_base_Tp_for_TMA_s', ...
        'Final_TMA_Hm0_m', 'Final_TMA_Hs_error_m', ...
        'Final_TMA_Tp_spec_s', 'Final_TMA_Tp_error_s', ...
        'Final_TMA_Hs_scale_factor'});

    AreaCheckTable = table( ...
        m0_target, ...
        trapz(f, S_JS_Hz), trapz(f, S_TMA_direct_Hz), trapz(f, S_TMA_final_Hz), ...
        4*sqrt(trapz(f, S_JS_Hz)), ...
        4*sqrt(trapz(f, S_TMA_direct_Hz)), ...
        4*sqrt(trapz(f, S_TMA_final_Hz)), ...
        'VariableNames', { ...
        'Target_m0', 'm0_JONSWAP_reference', 'm0_TMA_direct_FD_DC', 'm0_TMA_final_FD_HM', ...
        'Hm0_JONSWAP_reference_m', 'Hm0_TMA_direct_FD_DC_m', 'Hm0_TMA_final_FD_HM_m'});

    %% Time series
    TimeSeriesWideTable = table();
    TimeSeriesLongTable = table();
    TimeSeriesSummaryTable = table();
    WaveComponentsTable = table();
    etaMatrix_m = [];
    time_s = [];
    phase_common_rad = [];
    amplitudeRaw_m = [];
    amplitudeFinal_m = [];
    df_component_Hz = [];
    recordScaleFactor = ones(3, 1);

    if inp.generateTimeSeries
        if inp.timeSeries_dt_s <= 0 || inp.timeSeriesDuration_s <= 0
            error('timeSeriesDuration_s and timeSeries_dt_s must be positive.');
        end
        if inp.timeSeries_dt_s > 1/(2*max(f))
            warning('For current f_max, Nyquist requires dt <= %.6g s. Current dt = %.6g s.', ...
                1/(2*max(f)), inp.timeSeries_dt_s);
        end

        targetHm0BySpectrum = [param_JS.Hm0; param_TMA_direct.Hm0; param_TMA_final.Hm0];
        [time_s, etaMatrix_m, df_component_Hz, phase_common_rad, amplitudeRaw_m, amplitudeFinal_m, recordScaleFactor] = ...
            generateCommonPhaseTimeSeriesRecursive( ...
            f, S_matrix_Hz, inp.timeSeriesDuration_s, inp.timeSeries_dt_s, ...
            inp.timeSeriesPhaseMode, inp.timeSeriesPhaseSeed, inp.timeSeriesPhaseOffset_rad, ...
            inp.removeTimeSeriesMean, inp.forceTimeSeriesHm0ToSpectrum, targetHm0BySpectrum);

        TimeSeriesWideTable = table(time_s, ...
            etaMatrix_m(:,1), etaMatrix_m(:,2), etaMatrix_m(:,3), ...
            'VariableNames', { ...
            'time_s', ...
            'eta_JONSWAP_reference_m', ...
            'eta_TMA_direct_FD_DC_m', ...
            'eta_TMA_final_FD_HM_m'});

        nSamples = numel(time_s);
        SpectrumType_long = [repmat(spectrumNames(1), nSamples, 1); ...
                             repmat(spectrumNames(2), nSamples, 1); ...
                             repmat(spectrumNames(3), nSamples, 1)];
        time_s_long = [time_s; time_s; time_s];
        eta_m_long = [etaMatrix_m(:,1); etaMatrix_m(:,2); etaMatrix_m(:,3)];
        TimeSeriesLongTable = table(SpectrumType_long, time_s_long, eta_m_long, ...
            'VariableNames', {'SpectrumType', 'time_s', 'eta_m'});

        TimeSeriesSummaryTable = buildTimeSeriesSummaryTable( ...
            spectrumNames, time_s, etaMatrix_m, targetHm0BySpectrum, ...
            [param_JS.Tp_spec; param_TMA_direct.Tp_spec; param_TMA_final.Tp_spec], ...
            [param_JS.m0; param_TMA_direct.m0; param_TMA_final.m0], ...
            recordScaleFactor, inp);

        WaveComponentsTable = table( ...
            (1:numel(f)).', f, omega, df_component_Hz, phase_common_rad, ...
            S_matrix_Hz(:,1), S_matrix_Hz(:,2), S_matrix_Hz(:,3), ...
            S_matrix_rad(:,1), S_matrix_rad(:,2), S_matrix_rad(:,3), ...
            amplitudeRaw_m(:,1), amplitudeRaw_m(:,2), amplitudeRaw_m(:,3), ...
            amplitudeFinal_m(:,1), amplitudeFinal_m(:,2), amplitudeFinal_m(:,3), ...
            'VariableNames', { ...
            'component_index', 'f_Hz', 'omega_rad_s', 'df_component_Hz', 'common_phase_rad', ...
            'S_JONSWAP_reference_m2_Hz', ...
            'S_TMA_direct_FD_DC_m2_Hz', ...
            'S_TMA_final_FD_HM_m2_Hz', ...
            'S_JONSWAP_reference_m2_s_rad', ...
            'S_TMA_direct_FD_DC_m2_s_rad', ...
            'S_TMA_final_FD_HM_m2_s_rad', ...
            'amplitude_raw_JONSWAP_reference_m', ...
            'amplitude_raw_TMA_direct_FD_DC_m', ...
            'amplitude_raw_TMA_final_FD_HM_m', ...
            'amplitude_after_record_scaling_JONSWAP_reference_m', ...
            'amplitude_after_record_scaling_TMA_direct_FD_DC_m', ...
            'amplitude_after_record_scaling_TMA_final_FD_HM_m'});
    end

    %% Export spectra
    if inp.exportCSV
        writetable(FullCurveFrequencyTable, fullfile(spectraDir, 'spectra_all_three_spectra.csv'));
        writetable(SummaryTable, fullfile(spectraDir, 'spectra_summary.csv'));
    end


    if inp.exportExcel
        spectraXLSX = fullfile(spectraDir, '01_FULL_SPECTRA_DATA.xlsx');
        if exist(spectraXLSX, 'file'); delete(spectraXLSX); end
        writetable(FullCurveFrequencyTable, spectraXLSX, 'Sheet', 'Full_curve_frequency');
        writetable(FullCurvePeriodTable, spectraXLSX, 'Sheet', 'Full_curve_period');
        writetable(InputTable, spectraXLSX, 'Sheet', 'Input');
        writetable(SummaryTable, spectraXLSX, 'Sheet', 'Summary');
        writetable(ReductionTable, spectraXLSX, 'Sheet', 'FD_DC_reduction');
        writetable(MatchingTable, spectraXLSX, 'Sheet', 'FD_HM_matching');
        writetable(AreaCheckTable, spectraXLSX, 'Sheet', 'Area_check');
    end

    %% Export time-series data
    if inp.generateTimeSeries
        if inp.exportCSV
            writetable(TimeSeriesWideTable, fullfile(timeSeriesDir, 'wave_elevation_all_three_spectra.csv'));
            writetable(TimeSeriesSummaryTable, fullfile(timeSeriesDir, 'time_series_summary.csv'));
            writetable(WaveComponentsTable, fullfile(timeSeriesDir, 'common_phase_wave_components.csv'));
        end

        if inp.exportTimeSeriesExcel && height(TimeSeriesWideTable) <= 1048576
            tsXLSX = fullfile(timeSeriesDir, '02_WAVE_ELEVATION_TIMESERIES_WIDE.xlsx');
            if exist(tsXLSX, 'file'); delete(tsXLSX); end
            writetable(TimeSeriesWideTable, tsXLSX, 'Sheet', '01_time_series_wide');
            writetable(TimeSeriesSummaryTable, tsXLSX, 'Sheet', '02_time_series_summary');
            writetable(WaveComponentsTable, tsXLSX, 'Sheet', '03_common_phase_components');
        elseif inp.exportTimeSeriesExcel
            warning('Time series exceeds Excel row limit. Time-series Excel skipped for case %s.', inp.CaseID);
        end

        if inp.exportSIMA_ASC
            writeSIMAWaveElevationASC(fullfile(simaDir, 'SIMA_wave_elevation_01_JONSWAP_reference.asc'), ...
                etaMatrix_m(:,1), inp.timeSeries_dt_s, 'JONSWAP_reference', inp, caseName);
            writeSIMAWaveElevationASC(fullfile(simaDir, 'SIMA_wave_elevation_02_TMA_direct_FD_DC.asc'), ...
                etaMatrix_m(:,2), inp.timeSeries_dt_s, 'TMA_direct_FD_DC', inp, caseName);
            writeSIMAWaveElevationASC(fullfile(simaDir, 'SIMA_wave_elevation_03_TMA_final_FD_HM.asc'), ...
                etaMatrix_m(:,3), inp.timeSeries_dt_s, 'TMA_final_FD_HM', inp, caseName);
        end
    end

    %% Save MAT workspace for this case
    if inp.exportMAT
        save(fullfile(caseDir, '00_CASE_WORKSPACE_TABLES.mat'), ...
            'InputTable', 'FullCurveFrequencyTable', 'FullCurvePeriodTable', ...
            'SummaryTable', 'ReductionTable', 'MatchingTable', 'AreaCheckTable', ...
            'TimeSeriesWideTable', 'TimeSeriesLongTable', 'TimeSeriesSummaryTable', ...
            'WaveComponentsTable');
    end

    %% Export figures
    if inp.makeFigures
        makeCaseFigures(figureDir, caseName, inp, f, Phi, S_JS_Hz, S_TMA_direct_Hz, S_TMA_final_Hz, ...
            TimeSeriesWideTable, spectrumNames);
    end

    %% Write case README
    writeCaseReadme(fullfile(caseDir, '00_README_CASE_OUTPUT.txt'), caseName, inp, spectraDir, timeSeriesDir, simaDir, figureDir);

    if inp.showPreviewInCommandWindow
        fprintf('\nPreview of case %s time-series WIDE data:\n', inp.CaseID);
        if ~isempty(TimeSeriesWideTable)
            disp(TimeSeriesWideTable(1:min(8,height(TimeSeriesWideTable)), :));
        end
        fprintf('\nPreview of case %s spectra data:\n', inp.CaseID);
        disp(FullCurveFrequencyTable(1:min(8,height(FullCurveFrequencyTable)), :));
    end

    %% Case summary row
    CaseSummary = table( ...
        {inp.CaseID}, {caseName}, {caseDir}, Hs, Tp, h, ...
        param_JS.Hm0, param_TMA_direct.Hm0, param_TMA_final.Hm0, ...
        param_JS.Tp_spec, param_TMA_direct.Tp_spec, param_TMA_final.Tp_spec, ...
        param_TMA_direct.Hm0/Hs, (1-param_TMA_direct.Hm0/Hs)*100, ...
        fp_base_TMA, Tp_base_TMA, C_HM, ...
        inp.timeSeriesDuration_s, inp.timeSeries_dt_s, {inp.timeSeriesPhaseMode}, inp.timeSeriesPhaseSeed, ...
        'VariableNames', { ...
        'CaseID', 'CaseFolderName', 'CaseFolderPath', 'Hs_m', 'Tp_s', 'WaterDepth_m', ...
        'Hm0_JS_m', 'Hm0_FD_DC_m', 'Hm0_FD_HM_m', ...
        'Tp_spec_JS_s', 'Tp_spec_FD_DC_s', 'Tp_spec_FD_HM_s', ...
        'FD_DC_Hm0_over_Hs', 'FD_DC_Hs_reduction_percent', ...
        'FD_HM_internal_base_fp_Hz', 'FD_HM_internal_base_Tp_s', 'FD_HM_scale_factor', ...
        'TimeSeries_duration_s', 'TimeSeries_dt_s', 'Phase_mode', 'Phase_seed'});

    fprintf('\nCase output folder:\n%s\n', caseDir);
end

function [time_s, etaMatrix_m, df_component_Hz, phase_common_rad, amplitudeRaw_m, amplitudeFinal_m, recordScaleFactor] = ...
    generateCommonPhaseTimeSeriesRecursive(f, S_matrix_Hz, duration_s, dt_s, phaseMode, phaseSeed, phaseOffset_rad, removeMean, forceHm0, targetHm0BySpectrum)
    % Trigonometric recurrence avoids allocating an nTime-by-nFrequency matrix.

    f = f(:);
    S_matrix_Hz = max(S_matrix_Hz, 0);
    nFreq = numel(f);
    nSpec = size(S_matrix_Hz, 2);
    nSamples = floor(duration_s / dt_s) + 1;
    time_s = (0:nSamples-1).' * dt_s;

    df_component_Hz = frequencyBinWidths(f);
    phase_common_rad = deterministicPhaseVector(nFreq, phaseMode, phaseSeed, phaseOffset_rad);

    amplitudeRaw_m = sqrt(2 * S_matrix_Hz .* df_component_Hz);
    amplitudeFinal_m = amplitudeRaw_m;
    etaMatrix_m = zeros(nSamples, nSpec);

    cosTheta = cos(phase_common_rad);
    sinTheta = sin(phase_common_rad);
    cosStep = cos(2*pi*f*dt_s);
    sinStep = sin(2*pi*f*dt_s);

    for it = 1:nSamples
        etaMatrix_m(it, :) = cosTheta.' * amplitudeRaw_m;

        oldCos = cosTheta;
        cosTheta = cosTheta .* cosStep - sinTheta .* sinStep;
        sinTheta = sinTheta .* cosStep + oldCos .* sinStep;

        if mod(it, 10000) == 0
            r = sqrt(cosTheta.^2 + sinTheta.^2);
            cosTheta = cosTheta ./ r;
            sinTheta = sinTheta ./ r;
        end
    end

    recordScaleFactor = ones(nSpec, 1);

    for iSpec = 1:nSpec
        if removeMean
            etaMatrix_m(:, iSpec) = etaMatrix_m(:, iSpec) - mean(etaMatrix_m(:, iSpec));
        end

        if forceHm0
            currentHm0 = 4 * std(etaMatrix_m(:, iSpec), 1);
            if currentHm0 > 0
                recordScaleFactor(iSpec) = targetHm0BySpectrum(iSpec) / currentHm0;
                etaMatrix_m(:, iSpec) = etaMatrix_m(:, iSpec) * recordScaleFactor(iSpec);
                amplitudeFinal_m(:, iSpec) = amplitudeRaw_m(:, iSpec) * recordScaleFactor(iSpec);
            else
                warning('Cannot scale time series for spectrum %d because standard deviation is zero.', iSpec);
            end
        end
    end
end

function T = buildTimeSeriesSummaryTable(spectrumNames, time_s, etaMatrix_m, spectrumHm0, spectrumTp, spectrumM0, scaleFactor, inp)
    nSpec = numel(spectrumNames);
    Selected_spectrum = spectrumNames;
    Duration_s = repmat(time_s(end)-time_s(1), nSpec, 1);
    dt_s = repmat(inp.timeSeries_dt_s, nSpec, 1);
    Number_of_samples = repmat(numel(time_s), nSpec, 1);
    Phase_mode = repmat({inp.timeSeriesPhaseMode}, nSpec, 1);
    Phase_seed = repmat(inp.timeSeriesPhaseSeed, nSpec, 1);
    Same_phase_vector_for_all_spectra = true(nSpec, 1);
    Mean_removed = repmat(inp.removeTimeSeriesMean, nSpec, 1);
    Force_Hm0_to_spectrum = repmat(inp.forceTimeSeriesHm0ToSpectrum, nSpec, 1);

    TimeSeries_mean_m = mean(etaMatrix_m, 1).';
    TimeSeries_std_m = std(etaMatrix_m, 1, 1).';
    TimeSeries_Hm0_4std_m = 4 * TimeSeries_std_m;
    TimeSeries_min_m = min(etaMatrix_m, [], 1).';
    TimeSeries_max_m = max(etaMatrix_m, [], 1).';
    TimeSeries_peak_to_trough_m = TimeSeries_max_m - TimeSeries_min_m;

    T = table( ...
        Selected_spectrum, Duration_s, dt_s, Number_of_samples, ...
        Phase_mode, Phase_seed, Same_phase_vector_for_all_spectra, ...
        Mean_removed, Force_Hm0_to_spectrum, scaleFactor, ...
        spectrumHm0, spectrumTp, spectrumM0, ...
        TimeSeries_mean_m, TimeSeries_std_m, TimeSeries_Hm0_4std_m, ...
        TimeSeries_min_m, TimeSeries_max_m, TimeSeries_peak_to_trough_m, ...
        'VariableNames', { ...
        'Selected_spectrum', 'Duration_s', 'dt_s', 'Number_of_samples', ...
        'Phase_mode', 'Phase_seed', 'Same_phase_vector_for_all_spectra', ...
        'Mean_removed', 'Force_Hm0_to_spectrum', 'Finite_record_scale_factor', ...
        'Spectrum_Hm0_m', 'Spectrum_Tp_spec_s', 'Spectrum_m0', ...
        'TimeSeries_mean_m', 'TimeSeries_std_m', 'TimeSeries_Hm0_4std_m', ...
        'TimeSeries_min_m', 'TimeSeries_max_m', 'TimeSeries_peak_to_trough_m'});
end

function makeCaseFigures(figureDir, caseName, inp, f, Phi, S_JS_Hz, S_TMA_direct_Hz, S_TMA_final_Hz, TimeSeriesWideTable, spectrumNames)
    idxPlot = f >= inp.f_min_plot & f <= inp.f_max_plot;
    f_plot = f(idxPlot);

    fig1 = figure('Color','w');
    plot(f_plot, S_JS_Hz(idxPlot), 'LineWidth', 1.8); hold on;
    plot(f_plot, S_TMA_direct_Hz(idxPlot), 'LineWidth', 1.8);
    plot(f_plot, S_TMA_final_Hz(idxPlot), 'LineWidth', 1.8);
    grid on;
    xlabel('Frequency f [Hz]');
    ylabel('S_\eta(f) [m^2/Hz]');
    legend('JONSWAP reference', 'TMA direct FD-DC', 'TMA final FD-HM', 'Location', 'best');
    title(sprintf('%s: spectra, H_s = %.2f m, T_p = %.2f s, h = %.2f m', caseName, inp.Hs, inp.Tp, inp.h), 'Interpreter', 'none');
    xlim([inp.f_min_plot inp.f_max_plot]);
    saveas(fig1, fullfile(figureDir, '01_SPECTRA_Sf_vs_f.png'));

    fig2 = figure('Color','w');
    plot(f_plot, Phi(idxPlot), 'LineWidth', 1.8);
    grid on;
    xlabel('Frequency f [Hz]');
    ylabel('\Phi');
    title(sprintf('%s: finite-depth correction, h = %.2f m', caseName, inp.h), 'Interpreter', 'none');
    xlim([inp.f_min_plot inp.f_max_plot]);
    saveas(fig2, fullfile(figureDir, '02_TMA_Phi_vs_f.png'));

    fig3 = figure('Color','w');
    plot(f_plot, safeDivide(S_TMA_direct_Hz(idxPlot), S_JS_Hz(idxPlot)), 'LineWidth', 1.8); hold on;
    plot(f_plot, safeDivide(S_TMA_final_Hz(idxPlot), S_JS_Hz(idxPlot)), 'LineWidth', 1.8);
    grid on;
    xlabel('Frequency f [Hz]');
    ylabel('Ratio to JONSWAP [-]');
    legend('TMA direct FD-DC / JONSWAP', 'TMA final FD-HM / JONSWAP', 'Location', 'best');
    title(sprintf('%s: relative spectra', caseName), 'Interpreter', 'none');
    xlim([inp.f_min_plot inp.f_max_plot]);
    saveas(fig3, fullfile(figureDir, '03_RATIO_TO_JONSWAP.png'));

    if ~isempty(TimeSeriesWideTable)
        fig4 = figure('Color','w');
        timePlotMax_s = min(200.0, max(TimeSeriesWideTable.time_s));
        idxTimePlot = TimeSeriesWideTable.time_s <= timePlotMax_s;
        plot(TimeSeriesWideTable.time_s(idxTimePlot), TimeSeriesWideTable.eta_JONSWAP_reference_m(idxTimePlot), 'LineWidth', 1.0); hold on;
        plot(TimeSeriesWideTable.time_s(idxTimePlot), TimeSeriesWideTable.eta_TMA_direct_FD_DC_m(idxTimePlot), 'LineWidth', 1.0);
        plot(TimeSeriesWideTable.time_s(idxTimePlot), TimeSeriesWideTable.eta_TMA_final_FD_HM_m(idxTimePlot), 'LineWidth', 1.0);
        grid on;
        xlabel('Time t [s]');
        ylabel('\eta(t) [m]');
        legend(spectrumNames, 'Location', 'best', 'Interpreter', 'none');
        title(sprintf('%s: wave elevation preview, first %.0f s', caseName, timePlotMax_s), 'Interpreter', 'none');
        saveas(fig4, fullfile(figureDir, '04_WAVE_ELEVATION_PREVIEW.png'));
    end
end

function writeCaseReadme(path, caseName, inp, spectraDir, timeSeriesDir, simaDir, figureDir)
    fid = fopen(path, 'w');
    if fid < 0
        warning('Could not write README: %s', path);
        return;
    end
    c = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, 'Case output: %s\n', caseName);
    fprintf(fid, '========================================\n\n');
    fprintf(fid, 'Input:\n');
    fprintf(fid, '  Hs = %.10g m\n', inp.Hs);
    fprintf(fid, '  Tp = %.10g s\n', inp.Tp);
    fprintf(fid, '  h  = %.10g m\n', inp.h);
    fprintf(fid, '  gamma = %.10g\n', inp.gamma);
    fprintf(fid, '  TMA option = %s\n', inp.tmaOption);
    fprintf(fid, '  Time series duration = %.10g s\n', inp.timeSeriesDuration_s);
    fprintf(fid, '  Time series dt = %.10g s\n', inp.timeSeries_dt_s);
    fprintf(fid, '  Phase mode = %s\n', inp.timeSeriesPhaseMode);
    fprintf(fid, '  Phase seed = %d\n\n', inp.timeSeriesPhaseSeed);

    fprintf(fid, 'Folders:\n');
    fprintf(fid, '  Spectra data: %s\n', spectraDir);
    fprintf(fid, '  Time-series data: %s\n', timeSeriesDir);
    fprintf(fid, '  SIMA wave-elevation ASC files: %s\n\n', simaDir);

    fprintf(fid, 'Main files:\n');
    fprintf(fid, '  spectra/spectra_all_three_spectra.csv\n');
    fprintf(fid, '  wave_elevation/wave_elevation_all_three_spectra.csv\n');
    fprintf(fid, '  wave_elevation/common_phase_wave_components.csv\n');
    fprintf(fid, '  wave_elevation/time_series_summary.csv\n');
    fprintf(fid, '  sima_asc/SIMA_wave_elevation_01_JONSWAP_reference.asc\n');
    fprintf(fid, '  sima_asc/SIMA_wave_elevation_02_TMA_direct_FD_DC.asc\n');
    fprintf(fid, '  sima_asc/SIMA_wave_elevation_03_TMA_final_FD_HM.asc\n\n');

    fprintf(fid, 'Control principle:\n');
    fprintf(fid, '  The three wave elevation records use the same f vector, df vector, time vector,\n');
    fprintf(fid, '  and deterministic phase vector. Only spectral density S(f) differs.\n\n');

    fprintf(fid, 'SIMA ASC wave-elevation time-series format:\n');
    fprintf(fid, '  Line 1 = number of samples\n');
    fprintf(fid, '  Line 2 = time step\n');
    fprintf(fid, '  Line 3 = arbitrary text\n');
    fprintf(fid, '  Line 4 = arbitrary text\n');
    fprintf(fid, '  Line 5 onward = wave elevation eta(t) in m\n');
end

function writeRootReadme(path, outRoot, duration_s, dt_s, phaseMode, phaseSeed)
    fid = fopen(path, 'w');
    if fid < 0
        warning('Could not write root README: %s', path);
        return;
    end
    c = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, 'Root output folder\n');
    fprintf(fid, '==================\n\n');
    fprintf(fid, '%s\n\n', outRoot);
    fprintf(fid, 'Each environmental case has its own folder. Use these files inside each case:\n\n');
    fprintf(fid, '1) Spectra for analysis and plotting:\n');
    fprintf(fid, '   spectra/spectra_all_three_spectra.csv\n');
    fprintf(fid, '   spectra/spectra_summary.csv\n\n');
    fprintf(fid, '2) Time series for plotting and statistics:\n');
    fprintf(fid, '   wave_elevation/wave_elevation_all_three_spectra.csv\n');
    fprintf(fid, '   wave_elevation/time_series_summary.csv\n');
    fprintf(fid, '   wave_elevation/common_phase_wave_components.csv\n\n');
    fprintf(fid, '3) SIMA/SIMO wave-elevation time-series import:\n');
    fprintf(fid, '   sima_asc/*.asc\n\n');
    fprintf(fid, 'Time-series settings:\n');
    fprintf(fid, '   duration = %.10g s\n', duration_s);
    fprintf(fid, '   dt       = %.10g s\n', dt_s);
    fprintf(fid, '   phase mode = %s\n', phaseMode);
    fprintf(fid, '   phase seed = %d\n', phaseSeed);
end

function writeSIMAWaveElevationASC(filePath, eta_m, dt_s, selectedSpectrumName, inp, caseName)
    % SIMA/SIMO wave-elevation time-series format.
    fid = fopen(filePath, 'w');
    if fid < 0
        error('Cannot open ASC file for writing: %s', filePath);
    end
    c = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '%d\n', numel(eta_m));
    fprintf(fid, '%.12g\n', dt_s);
    fprintf(fid, 'SIMA WAVE ELEVATION TIME SERIES eta(t): source spectrum=%s, case=%s\n', selectedSpectrumName, caseName);
    fprintf(fid, 'Line 5 onward is eta(t) [m]; Hs=%.10g m, Tp=%.10g s, h=%.10g m, phase_mode=%s, phase_seed=%d\n', ...
        inp.Hs, inp.Tp, inp.h, inp.timeSeriesPhaseMode, inp.timeSeriesPhaseSeed);
    fprintf(fid, '%.12e\n', eta_m);
end

function S_shape = jonswapShape(f, fp, gamma, g)
    sigma = 0.09 * ones(size(f));
    sigma(f <= fp) = 0.07;
    r = exp( - (f/fp - 1).^2 ./ (2*sigma.^2) );
    alpha = 1.0;
    S_shape = alpha * g^2 / (2*pi)^4 .* f.^(-5) ...
        .* exp(-1.25 * (fp ./ f).^4) ...
        .* gamma.^r;
    S_shape(~isfinite(S_shape)) = 0;
    S_shape(f <= 0) = 0;
end

function S_norm = normalizeSpectrumToM0(f, S_raw, m0_target)
    m0_raw = trapz(f, S_raw);
    if m0_raw <= 0
        error('Raw spectrum has zero or negative area. Check frequency range.');
    end
    S_norm = S_raw * m0_target / m0_raw;
end

function k = waveNumberFiniteDepth(omega, h, g)
    k = omega.^2 / g;
    k_shallow = omega ./ sqrt(g*h);
    k = max(k, 0.5 * k_shallow);

    for iter = 1:100
        kh = k * h;
        tanh_kh = tanh(kh);
        sech2_kh = 1 ./ cosh(kh).^2;
        F  = g * k .* tanh_kh - omega.^2;
        dF = g * tanh_kh + g * k * h .* sech2_kh;
        dk = F ./ dF;
        k = k - dk;
        k(k < 0) = 0;
        if max(abs(dk)) < 1e-12
            break;
        end
    end
    k(~isfinite(k)) = 0;
end

function Phi = finiteDepthCorrection(omega, kh, h, g, tmaOption)
    switch lower(tmaOption)
        case 'exact'
            Phi = tanh(kh).^2 ./ (1 + 2*kh ./ sinh(2*kh));
        case 'piecewise'
            omega_h = omega * sqrt(h/g);
            Phi = zeros(size(omega_h));
            idx1 = omega_h <= 1;
            idx2 = omega_h > 1 & omega_h < 2;
            idx3 = omega_h >= 2;
            Phi(idx1) = 0.5 * omega_h(idx1).^2;
            Phi(idx2) = 1 - 0.5 * (2 - omega_h(idx2)).^2;
            Phi(idx3) = 1.0;
        otherwise
            error('Unknown tmaOption. Use exact or piecewise.');
    end
    Phi(~isfinite(Phi)) = 0;
    Phi(Phi < 0) = 0;
end

function fp_base = findBaseFpForFinalTMA_Tp(f, Phi, gamma, g, fp_target, Tp_target, m0_target)
    objective = @(fp) finalTMA_TpError(f, Phi, gamma, g, fp, Tp_target, m0_target);
    fp_min = max(min(f)*1.05, fp_target * 0.50);
    fp_max = min(max(f)*0.95, fp_target * 1.50);
    nGrid = 1501;
    fp_grid = linspace(fp_min, fp_max, nGrid).';
    absErr = zeros(size(fp_grid));
    for i = 1:nGrid
        absErr(i) = abs(objective(fp_grid(i)));
    end
    [~, idxBest] = min(absErr);
    fp_best = fp_grid(idxBest);
    i1 = max(idxBest - 3, 1);
    i2 = min(idxBest + 3, nGrid);
    try
        fp_refined = fminbnd(@(fp) abs(objective(fp)), fp_grid(i1), fp_grid(i2));
        if abs(objective(fp_refined)) <= abs(objective(fp_best))
            fp_best = fp_refined;
        end
    catch
    end
    fp_base = fp_best;
end

function err = finalTMA_TpError(f, Phi, gamma, g, fp_base, Tp_target, m0_target)
    S_base_shape = jonswapShape(f, fp_base, gamma, g);
    S_base = normalizeSpectrumToM0(f, S_base_shape, m0_target);
    S_tma = S_base .* Phi;
    S_tma = normalizeSpectrumToM0(f, S_tma, m0_target);
    param = spectralParameters(f, S_tma);
    err = param.Tp_spec - Tp_target;
end

function param = spectralParameters(f, S)
    m0 = trapz(f, S);
    m1 = trapz(f, f .* S);
    m2 = trapz(f, f.^2 .* S);
    Hm0 = 4 * sqrt(m0);
    [~, idxPeak] = max(S);
    fp_spec = f(idxPeak);
    Tp_spec = 1 / fp_spec;
    Tm01 = m0 / m1;
    Tm02 = sqrt(m0 / m2);
    param.m0 = m0;
    param.m1 = m1;
    param.m2 = m2;
    param.Hm0 = Hm0;
    param.fp_spec = fp_spec;
    param.Tp_spec = Tp_spec;
    param.Tm01 = Tm01;
    param.Tm02 = Tm02;
end

function df_component_Hz = frequencyBinWidths(f)
    f = f(:);
    if numel(f) < 2
        error('At least two frequency points are required.');
    end
    midPoints = 0.5 * (f(1:end-1) + f(2:end));
    firstEdge = f(1) - 0.5 * (f(2) - f(1));
    lastEdge = f(end) + 0.5 * (f(end) - f(end-1));
    if firstEdge < 0
        firstEdge = 0;
    end
    edges = [firstEdge; midPoints; lastEdge];
    df_component_Hz = diff(edges);
    if any(df_component_Hz <= 0)
        error('Computed non-positive frequency bin width. Check frequency vector.');
    end
end

function phase_rad = deterministicPhaseVector(n, phaseMode, phaseSeed, phaseOffset_rad)
    idx = (0:n-1).';
    switch lower(strtrim(char(phaseMode)))
        case {'deterministic_lcg', 'lcg'}
            m = 2147483647;
            a = 48271;
            x = double(mod(round(phaseSeed), m));
            if x <= 0
                x = 1;
            end
            u = zeros(n, 1);
            for ii = 1:n
                x = mod(a * x, m);
                u(ii) = x / m;
            end
            phase_rad = 2*pi*mod(u + phaseOffset_rad/(2*pi), 1);
        case {'deterministic_golden', 'golden', 'golden_angle'}
            goldenRatio = (1 + sqrt(5)) / 2;
            phase_rad = 2*pi*mod(idx / goldenRatio + phaseOffset_rad/(2*pi), 1);
        case {'zero', 'all_zero'}
            phase_rad = phaseOffset_rad * ones(n, 1);
        case {'linear', 'uniform'}
            phase_rad = mod(phaseOffset_rad + 2*pi*idx/n, 2*pi);
        otherwise
            error('Unknown phase mode: %s.', phaseMode);
    end
    phase_rad = mod(phase_rad, 2*pi);
end

function tag = makeCaseName(caseID, Hs, Tp, h, tmaOption)
    tag = sprintf('%s_Hs%.2f_Tp%.2f_h%.2f_%s', caseID, Hs, Tp, h, tmaOption);
    tag = strrep(tag, '.', 'p');
    tag = sanitizeFileTag(tag);
end

function tag = sanitizeFileTag(tag)
    tag = char(tag);
    tag = regexprep(tag, '[^A-Za-z0-9_\-]', '_');
    tag = regexprep(tag, '_+', '_');
end

function ensureFolder(folderPath)
    if ~exist(folderPath, 'dir')
        mkdir(folderPath);
    end
end

function y = safeDivide(a, b)
    y = zeros(size(a));
    idx = abs(b) > eps;
    y(idx) = a(idx) ./ b(idx);
    y(~idx) = NaN;
end

function openFolder(folderPath)
    try
        if ispc
            winopen(folderPath);
        elseif ismac
            system(['open ' char(34) folderPath char(34)]);
        else
            system(['xdg-open ' char(34) folderPath char(34) ' >/dev/null 2>&1 &']);
        end
    catch ME
        warning('Could not open folder automatically: %s', ME.message);
    end
end
