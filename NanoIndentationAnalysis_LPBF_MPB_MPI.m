%% NanoIndentation Analysis Toolbox
% Copyright (c) 2025 AYA MAJDOUB
% 
% This software is licensed under the MIT License.
% See LICENSE file in the project root for full license information.

%% FLEXIBLE CODE FOR MULTI-FILE ANALYSIS WITH ADAPTIVE HEATMAPS
% This code can process any number of files of different sizes
% and automatically generates heatmaps adapted to each dataset

clear; clc; close all;

%% CONFIGURATION 
fprintf('=== Multi-NanoHardness-Files-Analysis ===\n');
fprintf('This codes adapts automatically to the files numbers \n');
fprintf('and to the data size of each file \n\n');

% Propieties to analyse  (modify based on your dateSet and needs )
properties = {'HVIT', 'HIT', 'EIT'}; % add or clear propreties here 

%% Files Selection  (indetermined number )
fprintf('Select All Your Data Files ...\n');
[filenames, pathname] = uigetfile('*.txt', ' Select Files ', 'MultiSelect', 'on');

% cases where only one file is selected
if ~iscell(filenames)
    filenames = {filenames};
end

num_files = length(filenames);
fprintf('\nNumber of selected Files : %d\n', num_files);

% Request custom names for each file
sample_names = cell(1, num_files);
fprintf('\nName your Samples :\n');
for i = 1:num_files
    sample_names{i} = input(sprintf('Name of File %d (%s): ', i, filenames{i}), 's');
    if isempty(sample_names{i})
        sample_names{i} = sprintf('Sample_%d', i); % Default name
    end
end

%% DATA READING (adaptive depending on content)
data_raw = cell(1, num_files);
data_clean = cell(1, num_files);
data_info = struct(); % Infos Storage for each DataSet 

for i = 1:num_files
    filepath = fullfile(pathname, filenames{i});
    fprintf('\n--- Reading  %s (%s) ---\n', sample_names{i}, filenames{i});
    
    try
        % Read Files
        fid = fopen(filepath, 'r');
        lines = {};
        while ~feof(fid)
            line = fgetl(fid);
            if ischar(line)
                lines{end+1} = line;
            end
        end
        fclose(fid);
        
        % Measures Extraction
        measurements = [];
        for j = 1:length(lines)
            line = lines{j};
            if contains(line, 'Measurement')
                parts = strsplit(line, '\t');
                if length(parts) >= 7
                    vals = zeros(1, 6);
                    for k = 2:min(7, length(parts))
                        str_val = strrep(parts{k}, ',', '.');
                        str_val = strrep(str_val, ' ', '');
                        vals(k-1) = str2double(str_val);
                    end
                    measurements = [measurements; vals];
                end
            end
        end
        
        % Raw Data Storage 
        if ~isempty(measurements)
            data_raw{i}.EIT = measurements(:, 1);
            data_raw{i}.HIT = measurements(:, 2);
            data_raw{i}.HVIT = measurements(:, 3);
            data_raw{i}.hmax = measurements(:, 4);
            data_raw{i}.x = measurements(:, 5);
            data_raw{i}.y = measurements(:, 6);
            
            % Infos on the DataSet 
            data_info(i).name = sample_names{i};
            data_info(i).num_points = size(measurements, 1);
            data_info(i).x_range = [min(measurements(:, 5)), max(measurements(:, 5))];
            data_info(i).y_range = [min(measurements(:, 6)), max(measurements(:, 6))];
            
            fprintf('  ✓ Loaded Data : %d mesures\n', size(measurements, 1));
            fprintf('  ✓ X Range: [%.2f, %.2f] mm\n', data_info(i).x_range);
            fprintf('  ✓ Y Range: [%.2f, %.2f] mm\n', data_info(i).y_range);
        else
            fprintf('  ✗ NO DATA FOUND \n');
            data_info(i).name = sample_names{i};
            data_info(i).num_points = 0;
        end
        
    catch ME
        fprintf('  ✗ ERROR: %s\n', ME.message);
        data_info(i).name = sample_names{i};
        data_info(i).num_points = 0;
    end
end

%% Cleaning Data  (adaptative based on values)
fprintf('\n=== Data Cleaning  ===\n');

for i = 1:num_files
    if isempty(data_raw{i}) || data_info(i).num_points == 0
        continue;
    end
    
    fprintf('\n%s:\n', sample_names{i});
    
    orig = data_raw{i};
    clean = struct();
    
    % Cleaning for each property 
    for j = 1:length(properties)
        prop = properties{j};
        if isfield(orig, prop)
            values = orig.(prop);
            
            % Adaptive cleaning criteria (percentile-based)
            p_low = prctile(values, 1);
            p_high = prctile(values, 99);
            
            %  Cleaning Creteria 
            if strcmp(prop, 'HVIT')
                valid = values > max(0, p_low*0.5) & values < min(500, p_high*1.5) & ~isnan(values);
            elseif strcmp(prop, 'HIT')
                valid = values > max(0, p_low*0.5) & values < min(10, p_high*1.5) & ~isnan(values);
            elseif strcmp(prop, 'EIT')
                valid = values > max(0, p_low*0.5) & values < min(300, p_high*1.5) & ~isnan(values);
            else
                % Generic criterion for other properties
                valid = values > p_low*0.8 & values < p_high*1.2 & ~isnan(values);
            end
            
            % Cleaning application
            clean_values = values(valid);
            clean_x = orig.x(valid);
            clean_y = orig.y(valid);
            
            % Check the consistency of dimensions
            min_length = min([length(clean_values), length(clean_x), length(clean_y)]);
            
            clean.(prop) = clean_values(1:min_length);
            clean.([prop '_original']) = values;
            clean.x = clean_x(1:min_length);
            clean.y = clean_y(1:min_length);
            
            % Stats
            removed = length(values) - sum(valid);
            fprintf('  %s: %d Cleared Values (%.1f%%)\n', prop, removed, (removed/length(values))*100);
        end
    end
    
    data_clean{i} = clean;
    
    % Updated information
    if isfield(clean, 'x') && ~isempty(clean.x)
        data_info(i).num_points_clean = length(clean.x);
        data_info(i).x_unique = length(unique(round(clean.x, 6)));
        data_info(i).y_unique = length(unique(round(clean.y, 6)));
        
        fprintf('  Cleaned Points: %d\n', data_info(i).num_points_clean);
        fprintf('  Detected Grid: %d×%d\n', data_info(i).x_unique, data_info(i).y_unique);
    end
end

%% AUTOMATIC DETERMINATION OF HEATMAP SIZE
fprintf('\n=== HEATMAP SIZE DETERMINATION ===\n');

for i = 1:num_files
    if data_info(i).num_points == 0
        continue;
    end
    
    % Determine the optimal size of the heatmap
    if isfield(data_info(i), 'x_unique') && isfield(data_info(i), 'y_unique')
        % If you have a regular grid, use its dimensions.
        heatmap_size_x = data_info(i).x_unique;
        heatmap_size_y = data_info(i).y_unique;
    else
        % Otherwise, estimate based on the number of points.
        if isfield(data_info(i), 'num_points_clean')
            num_points = data_info(i).num_points_clean;
        else
            num_points = data_info(i).num_points;
        end
        
        if num_points >= 625
            suggested_size = 25;  % You can add whatever size you want 
        elseif num_points >= 400
            suggested_size = 20;
        elseif num_points >= 225
            suggested_size = 15;
        elseif num_points >= 100
            suggested_size = 10;
        elseif num_points >= 25
            suggested_size = 5;
        else
            suggested_size = 3;
        end
        
        heatmap_size_x = suggested_size;
        heatmap_size_y = suggested_size;
    end
    
    data_info(i).heatmap_size = [heatmap_size_x, heatmap_size_y];
    fprintf('%s: Heatmap %d×%d\n', sample_names{i}, heatmap_size_x, heatmap_size_y);
end

%% GENERATION OF ADAPTIVE HEAT MAPS
% Number of columns for display (adjusted automatically)
if num_files <= 3
    cols = num_files;
    rows = 1;
elseif num_files <= 6
    cols = 3;
    rows = 2;
elseif num_files <= 9
    cols = 3;
    rows = 3;
elseif num_files <= 12
    cols = 4;
    rows = 3;
else
    cols = 5;
    rows = ceil(num_files / 5);
end

for prop_idx = 1:length(properties)
    prop = properties{prop_idx};
    
    figure('Name', sprintf('Heatmaps %s - All Sizes', prop), 'Position', [50+prop_idx*30, 50, 300*cols, 250*rows]);
    
    % Calculation of the overall scale for visual consistency
    all_values = [];
    for i = 1:num_files
        if isfield(data_clean{i}, prop)
            all_values = [all_values; data_clean{i}.(prop)];
        end
    end
    
    if ~isempty(all_values)
        % Filter invalid values for scale calculation
        all_values_clean = all_values(~isnan(all_values) & ~isinf(all_values));
        
        if ~isempty(all_values_clean)
            global_min = prctile(all_values_clean, 2);
            global_max = prctile(all_values_clean, 98);
        else
            global_min = 0;
            global_max = 1;
        end
        
        for i = 1:num_files
            subplot(rows, cols, i);
            
            if isfield(data_clean{i}, prop) && isfield(data_clean{i}, 'x') && isfield(data_clean{i}, 'y')
                values = data_clean{i}.(prop);
                x_pos = data_clean{i}.x;
                y_pos = data_clean{i}.y;
                
                if ~isempty(values) && length(values) >= 3
                    % Check dimensional consistency
                    min_len = min([length(values), length(x_pos), length(y_pos)]);
                    values = values(1:min_len);
                    x_pos = x_pos(1:min_len);
                    y_pos = y_pos(1:min_len);
                    
                    try
                        % Get the heatmap size for this sample
                        hmap_size_x = data_info(i).heatmap_size(1);
                        hmap_size_y = data_info(i).heatmap_size(2);
                        
                        % Create Grid
                        x_min = min(x_pos); x_max = max(x_pos);
                        y_min = min(y_pos); y_max = max(y_pos);
                        
                        x_grid = linspace(x_min, x_max, hmap_size_x);
                        y_grid = linspace(y_min, y_max, hmap_size_y);
                        [X_grid, Y_grid] = meshgrid(x_grid, y_grid);
                        
                        % Interpolation 
                        if length(values) >= hmap_size_x * hmap_size_y * 0.7
                            % Enough points: cubic interpolation
                            Z = griddata(x_pos, y_pos, values, X_grid, Y_grid, 'cubic');
                        elseif length(values) >= hmap_size_x * hmap_size_y * 0.3
                            % Average points: linear interpolation
                            Z = griddata(x_pos, y_pos, values, X_grid, Y_grid, 'linear');
                        else
                            % Few points: nearest neighbor
                            Z = griddata(x_pos, y_pos, values, X_grid, Y_grid, 'nearest');
                        end
                        
                        % Fill in the remaining NaNs
                        if any(isnan(Z(:)))
                            Z_nearest = griddata(x_pos, y_pos, values, X_grid, Y_grid, 'nearest');
                            Z(isnan(Z)) = Z_nearest(isnan(Z));
                        end
                        
                        % If there are still NaNs, use the average
                        if any(isnan(Z(:)))
                            Z(isnan(Z)) = mean(values);
                        end
                        
                        % Displaying the heatmap with real coordinates
                        imagesc(x_grid, y_grid, Z);
                        colormap(hot);
                        clim([global_min, global_max]);
                        
                        % Added white dots on the actual measurement positions
                        hold on;
                        scatter(x_pos, y_pos, 10, 'w', 'filled', 'MarkerEdgeColor', 'k', 'MarkerEdgeAlpha', 0.2, 'MarkerFaceAlpha', 0.4);
                        hold off;
                        
                        % Axis configuration with real coordinates
                        axis equal tight;
                        set(gca, 'YDir', 'normal');
                        xlim([x_min x_max]);
                        ylim([y_min y_max]);
                        
                        % Title infos
                        title(sprintf('%s\n(%d×%d, N=%d)', sample_names{i}, hmap_size_x, hmap_size_y, length(values)), ...
                            'FontSize', 8, 'Interpreter', 'Latex');
                        
                        % Labels with real coordinates
                        xlabel('X [mm]', 'FontSize', 8);
                        ylabel('Y [mm]', 'FontSize', 8);
                        
                        % Add a grid to better view the coordinates
                        grid on;
                        set(gca, 'GridAlpha', 0.2);
                        
                    catch ME
                        fprintf('Error heatmap %s: %s\n', sample_names{i}, ME.message);
                        % Eroor
                        text(0.5, 0.5, sprintf('Error\n%d points', length(values)), ...
                            'HorizontalAlignment', 'center', 'Units', 'normalized');
                        title(sample_names{i}, 'Interpreter', 'none');
                    end
                else
                    % Insufficient data
                    text(0.5, 0.5, sprintf('Data\ninsufficient\n(%d points)', length(values)), ...
                        'HorizontalAlignment', 'center', 'Units', 'normalized');
                    title(sample_names{i}, 'Interpreter', 'none');
                end
            else
                % Missed DATA
                text(0.5, 0.5, 'NO DATA!', 'HorizontalAlignment', 'center', 'Units', 'normalized');
                title(sample_names{i}, 'Interpreter', 'none');
            end
        end
        
        % Common Colorbar 
        cb = colorbar('Position', [0.93, 0.15, 0.02, 0.7]);
        ylabel(cb, sprintf('%s', prop), 'FontSize', 10);
        
        sgtitle(sprintf('%s - Heatmaps ', prop), 'FontSize', 14);
    end
end

%% SCATTER PLOTS 
for prop_idx = 1:length(properties)
    prop = properties{prop_idx};
    
    figure('Name', sprintf('Scatter %s - Multi-Samples', prop), 'Position', [100+prop_idx*30, 100, 300*cols, 250*rows]);
    
    % Global scale
    all_values = [];
    for i = 1:num_files
        if isfield(data_clean{i}, prop)
            all_values = [all_values; data_clean{i}.(prop)];
        end
    end
    
    if ~isempty(all_values)
        % Filter invalid values for scale calculation
        all_values_clean = all_values(~isnan(all_values) & ~isinf(all_values));
        
        if ~isempty(all_values_clean)
            global_min = min(all_values_clean);
            global_max = max(all_values_clean);
            
            % Check that min and max are different
            if global_min >= global_max
                global_max = global_min + 1;
            end
        else
            global_min = 0;
            global_max = 1;
        end
        
        for i = 1:num_files
            subplot(rows, cols, i);
            
            if isfield(data_clean{i}, prop) && isfield(data_clean{i}, 'x') && isfield(data_clean{i}, 'y')
                values = data_clean{i}.(prop);
                x_pos = data_clean{i}.x;
                y_pos = data_clean{i}.y;
                
                if ~isempty(values)
                    % Check the consistency of dimensions
                    min_len = min([length(values), length(x_pos), length(y_pos)]);
                    values = values(1:min_len);
                    x_pos = x_pos(1:min_len);
                    y_pos = y_pos(1:min_len);
                    
                    % Filter out NaN and invalid values
                    valid_idx = ~isnan(values) & ~isinf(values) & ~isnan(x_pos) & ~isnan(y_pos);
                    values = values(valid_idx);
                    x_pos = x_pos(valid_idx);
                    y_pos = y_pos(valid_idx);
                    
                    if ~isempty(values) && length(values) >= 3
                        % Marker size adapted to the number of points
                        if length(values) > 200
                            marker_size = 20;
                        elseif length(values) > 100
                            marker_size = 30;
                        elseif length(values) > 50
                            marker_size = 35;
                        else
                            marker_size = 40;
                        end
                        
                        try
                            % Ensure that values is a column vector
                            values = values(:);
                            scatter(x_pos, y_pos, marker_size, values, 'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 0.3);
                            colormap(hot);
                            if ~isempty(all_values) && global_min < global_max
                                clim([global_min, global_max]);
                            end
                        catch ME
                            % If there is an error with colors, use a fixed color.
                            fprintf('  Scatter WARNING! %s: %s\n', sample_names{i}, ME.message);
                            scatter(x_pos, y_pos, marker_size, 'filled', 'MarkerFaceColor', [0.8, 0.4, 0.2], 'MarkerEdgeColor', 'k', 'LineWidth', 0.3);
                        end
                        
                        axis equal;
                        xlabel('X [mm]', 'FontSize', 8);
                        ylabel('Y [mm]', 'FontSize', 8);
                        title(sprintf('%s (N=%d)', sample_names{i}, length(values)), 'FontSize', 10, 'Interpreter', 'none');
                        
                        % Stats
                        text(0.02, 0.98, sprintf('μ: %.1f\nσ: %.1f\nCV: %.1f%%', ...
                            mean(values), std(values), (std(values)/mean(values))*100), ...
                            'Units', 'normalized', 'VerticalAlignment', 'top', ...
                            'BackgroundColor', 'white', 'FontSize', 8, 'EdgeColor', 'black');
                    else
                        text(0.5, 0.5, sprintf('Data\ninsufficient\n(%d validated points)', length(values)), ...
                            'HorizontalAlignment', 'center', 'Units', 'normalized');
                        title(sample_names{i}, 'Interpreter', 'none');
                    end
                else
                    text(0.5, 0.5, 'NO DATA!', 'HorizontalAlignment', 'center', 'Units', 'normalized');
                    title(sample_names{i}, 'Interpreter', 'none');
                end
            else
                text(0.5, 0.5, 'Missed Data', 'HorizontalAlignment', 'center', 'Units', 'normalized');
                title(sample_names{i}, 'Interpreter', 'none');
            end
        end
        
        % Common Colorbar 
        cb = colorbar('Position', [0.93, 0.15, 0.02, 0.7]);
        ylabel(cb, sprintf('%s', prop), 'FontSize', 10);
        
        sgtitle(sprintf('%s - Scatter plots ', prop), 'FontSize', 14);
    end
end

%% STATS COMPARISON
figure('Name', 'Statistics Comparaison ', 'Position', [300, 300, 1200, 800]);

for prop_idx = 1:length(properties)
    prop = properties{prop_idx};
    
    % Stats Collection
    means = []; stds = []; medians = []; labels = {};
    
    for i = 1:num_files
        if isfield(data_clean{i}, prop) && ~isempty(data_clean{i}.(prop))
            values = data_clean{i}.(prop);
            means(end+1) = mean(values);
            stds(end+1) = std(values);
            medians(end+1) = median(values);
            labels{end+1} = sample_names{i};
        end
    end
    
    if ~isempty(means)
        subplot(1, 3, prop_idx);
        
        x = 1:length(means);
        bar(x, means, 'FaceColor', [0.3, 0.6, 0.9]);
        hold on;
        errorbar(x, means, stds, 'k.', 'LineWidth', 2);
        
        xlabel('Sample');
        ylabel(prop);
        title(sprintf('%s - MEAN ± STD', prop));
        set(gca, 'XTick', x, 'XTickLabel', labels);
        xtickangle(45);
        grid on;
        
       
     end
end
% 
% sgtitle('');

%% INFOS SUMMARY
fprintf('\n=== RÉSUMÉ DE L''ANALYSE ===\n');
fprintf('%-30s %-15s %-15s %-20s\n', 'Échantillon', 'Points bruts', 'Points nettoyés', 'Taille heatmap');
fprintf('%-30s %-15s %-15s %-20s\n', repmat('-', 1, 30), repmat('-', 1, 15), repmat('-', 1, 15), repmat('-', 1, 20));

for i = 1:num_files
    if data_info(i).num_points > 0
        if isfield(data_info(i), 'num_points_clean')
            points_clean = data_info(i).num_points_clean;
        else
            points_clean = data_info(i).num_points;
        end
        
        fprintf('%-30s %-15d %-15d %-20s\n', ...
            sample_names{i}, ...
            data_info(i).num_points, ...
            points_clean, ...
            sprintf('%d×%d', data_info(i).heatmap_size(1), data_info(i).heatmap_size(2)));
    else
        fprintf('%-30s %-15s %-15s %-20s\n', sample_names{i}, 'N/A', 'N/A', 'N/A');
    end
end

%% Results Table
fprintf('\n=== Results Table ===\n');
fprintf('%-30s %-10s %-10s %-10s %-10s %-10s\n', 'Sample', 'Proprety', 'Mean', 'Median', 'std', 'CV%');
fprintf('%-30s %-10s %-10s %-10s %-10s %-10s\n', repmat('-', 1, 30), repmat('-', 1, 10), repmat('-', 1, 10), repmat('-', 1, 10), repmat('-', 1, 10), repmat('-', 1, 10));

for i = 1:num_files
    for j = 1:length(properties)
        prop = properties{j};
        if isfield(data_clean{i}, prop) && ~isempty(data_clean{i}.(prop))
            values = data_clean{i}.(prop);
            fprintf('%-30s %-10s %-10.2f %-10.2f %-10.2f %-10.1f\n', ...
                sample_names{i}, prop, mean(values), median(values), std(values), (std(values)/mean(values))*100);
        end
    end
end

%% Save
fprintf('\n=== Save Results ===\n');

% Create Results Folder
output_folder = sprintf('Results_Analysis%s', datestr(now, 'yyyymmdd_HHMMSS'));
mkdir(output_folder);

% Save all Figures
fig_handles = findall(0, 'Type', 'figure');
for i = 1:length(fig_handles)
    fig_name = get(fig_handles(i), 'Name');
    if ~isempty(fig_name)
        safe_name = regexprep(fig_name, '[^\w\s-]', '');
        safe_name = regexprep(safe_name, '\s+', '_');
        
        saveas(fig_handles(i), fullfile(output_folder, [safe_name '.png']));
        saveas(fig_handles(i), fullfile(output_folder, [safe_name '.fig']));
    end
end

% Save Data
save(fullfile(output_folder, 'Data.mat'), 'data_raw', 'data_clean', 'data_info', 'sample_names');

% Create Summary
report_file = fullfile(output_folder, 'Summary_NanoIndenatation.txt');
fid = fopen(report_file, 'w');
if fid ~= -1
    fprintf(fid, 'Summary\n');
    fprintf(fid, '=================\n');
    fprintf(fid, 'Date: %s\n', datestr(now));
    fprintf(fid, 'Files Number: %d\n\n', num_files);
    
    for i = 1:num_files
        if isfield(data_info(i), 'num_points_clean')
            points_clean = data_info(i).num_points_clean;
        else
            points_clean = data_info(i).num_points;
        end
        
        fprintf(fid, 'Samples %d: %s\n', i, sample_names{i});
        fprintf(fid, '  Files: %s\n', filenames{i});
        fprintf(fid, '  Points: %d (raw), %d (Cleaned)\n', data_info(i).num_points, points_clean);
        if isfield(data_info(i), 'heatmap_size')
            fprintf(fid, '  Heatmap: %d×%d\n\n', data_info(i).heatmap_size(1), data_info(i).heatmap_size(2));
        else
            fprintf(fid, '  Heatmap: N/A\n\n');
        end
    end
    
    fclose(fid);
end

fprintf('Results Saved in : %s\n', output_folder);
fprintf('\nDone!\n');

%% OPTIMIZED HEATMAP ANALYSIS - SEPARATE GRAPHS
% Selection of MPB contours on HVIT only, automatic application to other properties
% Generation of individual graphs for each analysis

function analyze_melt_pool_boundaries_optimized(data_clean, sample_names, properties)
    
    %% INDENTATION PARAMETERS
    indent_size_um = 7;      % Indent size( µm )
    spacing_um = 30;         % Spacing between indents centers ( µm )
    
    fprintf('\n=== Melting Pool Boundaries & Inerior Anaysis (MPB&MPI)===\n');
    fprintf('Configuration:\n');
    fprintf('- Indent Size: %d µm\n', indent_size_um);
    fprintf('- Spacing: %d µm\n', spacing_um);
    fprintf('- Grid: %.1f × %.1f µm per cellule\n', spacing_um, spacing_um);
    
    %% Sample Selection 
    if length(sample_names) == 1
        sample_idx = 1;
    else
        fprintf('\nAvailable Samples:\n');
        for i = 1:length(sample_names)
            fprintf('%d. %s\n', i, sample_names{i});
        end
        sample_idx = input('Sample Number : ');
        if isempty(sample_idx), sample_idx = 1; end
    end
    
    %% PART 1:  HEATMAPS Generation
    fprintf('\n---  HEATMAPS Creation---\n');
    
    % Data storage for later analysis
    heatmap_data = struct();
    
    for prop_idx = 1:length(properties)
        prop = properties{prop_idx};
        
        if ~isfield(data_clean{sample_idx}, prop)
            continue;
        end
        
        % Data recovery
        values = data_clean{sample_idx}.(prop);
        x_pos = data_clean{sample_idx}.x * 1000; % Conversion mm -> µm
        y_pos = data_clean{sample_idx}.y * 1000; % Conversion mm -> µm
        
        % Synchronization and filtering
        min_len = min([length(values), length(x_pos), length(y_pos)]);
        values = values(1:min_len);
        x_pos = x_pos(1:min_len);
        y_pos = y_pos(1:min_len);
        
        valid = ~isnan(values) & ~isinf(values);
        values = values(valid);
        x_pos = x_pos(valid);
        y_pos = y_pos(valid);
        
        if isempty(values)
            continue;
        end
        
        % Creation of the aligned grid
        x_min = min(x_pos); x_max = max(x_pos);
        y_min = min(y_pos); y_max = max(y_pos);
        
        x_grid = x_min:spacing_um:x_max;
        y_grid = y_min:spacing_um:y_max;
        
        [X_grid, Y_grid] = meshgrid(x_grid, y_grid);
        
        % Creating the values matrix
        Z = NaN(length(y_grid), length(x_grid));
        
        for i = 1:length(x_grid)
            for j = 1:length(y_grid)
                distances = sqrt((x_pos - x_grid(i)).^2 + (y_pos - y_grid(j)).^2);
                [min_dist, idx] = min(distances);
                if min_dist < spacing_um/2
                    Z(j, i) = values(idx);
                end
            end
        end
        
        % Interpolation for missing values
        if any(isnan(Z(:)))
            [X_fine, Y_fine] = meshgrid(linspace(x_min, x_max, length(x_grid)*5), ...
                                       linspace(y_min, y_max, length(y_grid)*5));
            Z_fine = griddata(x_pos, y_pos, values, X_fine, Y_fine, 'cubic');%Cubic: For dense data (>70% grid coverage)
            
            for i = 1:length(x_grid)
                for j = 1:length(y_grid)
                    if isnan(Z(j, i))
                        [~, ix] = min(abs(X_fine(1, :) - x_grid(i)));
                        [~, iy] = min(abs(Y_fine(:, 1) - y_grid(j)));
                        if ix > 0 && ix <= size(Z_fine, 2) && iy > 0 && iy <= size(Z_fine, 1)
                            Z(j, i) = Z_fine(iy, ix);
                        end
                    end
                end
            end
        end
        
        % Storage
        heatmap_data.(prop).Z = Z;
        heatmap_data.(prop).X = X_grid;
        heatmap_data.(prop).Y = Y_grid;
        heatmap_data.(prop).values = values;
        heatmap_data.(prop).x_pos = x_pos;
        heatmap_data.(prop).y_pos = y_pos;
        heatmap_data.(prop).x_grid = x_grid;
        heatmap_data.(prop).y_grid = y_grid;
        
        % HEATMAPS
        figure('Name', sprintf('Heatmap %s - %s', prop, sample_names{sample_idx}), ...
               'Position', [50 + prop_idx*30, 50 + prop_idx*30, 800, 600]);
        
        imagesc(x_grid, y_grid, Z);
        colormap(hot);
        colorbar;
        
        hold on;
        % Indent circles
        for i = 1:length(x_pos)
            rectangle('Position', [x_pos(i)-indent_size_um/2, y_pos(i)-indent_size_um/2, ...
                                 indent_size_um, indent_size_um], ...
                     'Curvature', [1, 1], 'EdgeColor', 'w', 'LineWidth', 0.5);
        end
        
        % Spacing Grid
        for i = 1:length(x_grid)
            plot([x_grid(i), x_grid(i)], [y_min, y_max], 'w:', 'LineWidth', 0.3);
        end
        for j = 1:length(y_grid)
            plot([x_min, x_max], [y_grid(j), y_grid(j)], 'w:', 'LineWidth', 0.3);
        end
        
        axis equal tight;
        xlabel('X [µm]', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel('Y [µm]', 'FontSize', 12, 'FontWeight', 'bold');
        title(sprintf('%s -Indent grid (%d µm, Spacing  %d µm)', ...
              prop, indent_size_um, spacing_um), 'FontSize', 14, 'FontWeight', 'bold');
        set(gca, 'YDir', 'normal', 'FontSize', 11);
        
        % Edge Stats 
        text(0.02, 0.98, sprintf('µ = %.2f\nσ = %.2f\nMin = %.2f\nMax = %.2f', ...
            mean(values), std(values), min(values), max(values)), ...
            'Units', 'normalized', 'VerticalAlignment', 'top', ...
            'BackgroundColor', 'white', 'EdgeColor', 'k', 'FontSize', 10);
    end
    
    %% PART 2: MPB CONTOUR SELECTION (HVIT)
    fprintf('\n--- MPB CONTOUR SELECTION (HVIT) ---\n');
    
    % Verification
    hvit_prop = '';
    possible_hvit = {'HVIT', 'hvit', 'Hvit', 'VICKERS', 'vickers', 'HV'};
    for p = possible_hvit
        if isfield(heatmap_data, p{1})
            hvit_prop = p{1};
            break;
        end
    end
    
    if isempty(hvit_prop)
        fprintf('HVIT NOT FOUND ! Use of the first available property.\n');
        props_available = fieldnames(heatmap_data);
        hvit_prop = props_available{1};
    end
    
    fprintf('Property used for selection: %s\n', hvit_prop);
    
    % GRAPH For the selection 
    fig_select = figure('Name', sprintf('MPB Selection - %s', hvit_prop), ...
                       'Position', [200, 150, 1000, 800]);
    
    % Displaying the HVIT heat map
    imagesc(heatmap_data.(hvit_prop).x_grid, heatmap_data.(hvit_prop).y_grid, ...
            heatmap_data.(hvit_prop).Z);
    colormap(hot);
    c = colorbar;
    ylabel(c, hvit_prop, 'FontSize', 12, 'FontWeight', 'bold');
    
    hold on;
    % Contours for better visibility
    contour(heatmap_data.(hvit_prop).X, heatmap_data.(hvit_prop).Y, ...
            heatmap_data.(hvit_prop).Z, 10, 'w-', 'LineWidth', 0.5);
    
    % Measurement points
    plot(heatmap_data.(hvit_prop).x_pos, heatmap_data.(hvit_prop).y_pos, ...
         'w.', 'MarkerSize', 8);
    
    axis equal tight;
    xlabel('X [µm]', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Y [µm]', 'FontSize', 12, 'FontWeight', 'bold');
    title(sprintf(' MPB Contour Selection On %s', hvit_prop), ...
          'FontSize', 14, 'FontWeight', 'bold');
    set(gca, 'YDir', 'normal', 'FontSize', 11);
    
    % Instructions
    text(0.5, 1.05, 'CLICK on the CONTOUR points (MPB) - ENTER to finish', ...
        'Units', 'normalized', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'FontSize', 12, 'Color', 'red');
    
    fprintf('\nMPB Contours Selection:\n');
    fprintf('- CLIC: select a contour point(MPB)\n');
    fprintf('- ENTRY: complete selection\n');
    fprintf('- The other points will automatically be considered as MPI. \n\n');
    
    % Interactive selection
    MPB_indices = [];
    selected_points = [];
    
    while true
        [x_click, y_click, button] = ginput(1);
        
        if isempty(button)  % Pressed starter
            break;
        end
        
        % Find the nearest point
        distances = sqrt((heatmap_data.(hvit_prop).x_pos - x_click).^2 + ...
                        (heatmap_data.(hvit_prop).y_pos - y_click).^2);
        [~, idx] = min(distances);
        
        % Avoid duplicates
        if ~ismember(idx, MPB_indices)
            MPB_indices = [MPB_indices, idx];
            
            x_selected = heatmap_data.(hvit_prop).x_pos(idx);
            y_selected = heatmap_data.(hvit_prop).y_pos(idx);
            selected_points = [selected_points; x_selected, y_selected];
            
            plot(x_selected, y_selected, 'ro', 'MarkerSize', 12, 'MarkerFaceColor', 'r', 'LineWidth', 2);
            text(x_selected, y_selected, sprintf(' %d', length(MPB_indices)), ...
                'Color', 'r', 'FontWeight', 'bold', 'FontSize', 10);
            
            fprintf('  MPB %d: (%.1f, %.1f)\n', length(MPB_indices), x_selected, y_selected);
        end
    end
    
    fprintf('\nFinish Selection: %d points MPB Selected\n', length(MPB_indices));
    
    % Create MPI indices (all other points)
    all_indices = 1:length(heatmap_data.(hvit_prop).x_pos);
    MPI_indices = setdiff(all_indices, MPB_indices);
    
    fprintf('MPI Points: %d\n', length(MPI_indices));
    
    %% PART 3: Application to all properties
    fprintf('\n--- Application to all properties ---\n');
    
    results = struct();
    prop_names = fieldnames(heatmap_data);
    
    for i = 1:length(prop_names)
        prop = prop_names{i};
        
        %  MPB et MPI values based on selected indexes 
        MPB_values = heatmap_data.(prop).values(MPB_indices);
        MPI_values = heatmap_data.(prop).values(MPI_indices);
        
        % Stats Calculations
        results.(prop).MPB_mean = mean(MPB_values);
        results.(prop).MPB_std = std(MPB_values);
        results.(prop).MPB_n = length(MPB_values);
        
        results.(prop).MPI_mean = mean(MPI_values);
        results.(prop).MPI_std = std(MPI_values);
        results.(prop).MPI_n = length(MPI_values);
        
        results.(prop).ratio = results.(prop).MPB_mean / results.(prop).MPI_mean;
        results.(prop).diff_percent = (results.(prop).MPB_mean - results.(prop).MPI_mean) / results.(prop).MPI_mean * 100;
        
        % Test stat
        [h, p] = ttest2(MPB_values, MPI_values);
        results.(prop).pvalue = p;
        results.(prop).significant = h;
        
        fprintf('%s: MPB=%.2f±%.2f, MPI=%.2f±%.2f, Ratio=%.3f, Diff=%.1f%%, p=%.4f\n', ...
            prop, results.(prop).MPB_mean, results.(prop).MPB_std, ...
            results.(prop).MPI_mean, results.(prop).MPI_std, ...
            results.(prop).ratio, results.(prop).diff_percent, results.(prop).pvalue);
    end
    
    %% PART 4: THE MAIN COMPARATIVE GRAPH
    fprintf('\n--- GENERATION OF THE MAIN COMPARATIVE GRAPH ---\n');
    
    fig_main = figure('Name', 'Graphique Principal - Comparaison MPB vs MPI', ...
                     'Position', [100, 100, 1000, 700]);
    
    % Preparing data
    n_props = length(prop_names);
    MPB_means = zeros(1, n_props);
    MPI_means = zeros(1, n_props);
    MPB_stds = zeros(1, n_props);
    MPI_stds = zeros(1, n_props);
    
    for i = 1:n_props
        prop = prop_names{i};
        MPB_means(i) = results.(prop).MPB_mean;
        MPI_means(i) = results.(prop).MPI_mean;
        MPB_stds(i) = results.(prop).MPB_std;
        MPI_stds(i) = results.(prop).MPI_std;
    end
    
    % Main chart (your reference style)
    x = 1:n_props;
    width = 0.35;
    
    % MPB & MPI Bars
    b1 = bar(x - width/2, MPB_means, width, 'FaceColor', [0.4 0.5 0.8], 'EdgeColor', 'k', 'LineWidth', 1.5);
    hold on;
    b2 = bar(x + width/2, MPI_means, width, 'FaceColor', [0.8 0.5 0.3], 'EdgeColor', 'k', 'LineWidth', 1.5);
    
    % Error Bars
    errorbar(x - width/2, MPB_means, MPB_stds, 'k.', 'LineWidth', 2, 'CapSize', 8);
    errorbar(x + width/2, MPI_means, MPI_stds, 'k.', 'LineWidth', 2, 'CapSize', 8);
    
    % Layout
    set(gca, 'XTick', x, 'XTickLabel', prop_names, 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Mean Value', 'FontSize', 14, 'FontWeight', 'bold');
    title(sprintf('Comparision MPB vs MPI - %s', sample_names{sample_idx}), ...
          'FontSize', 16, 'FontWeight', 'bold');
    legend({'MPB (Contours)', 'MPI (Interior)'}, 'Location', 'best', 'FontSize', 12);
    grid on;
    grid minor;
    
    %Enhancement 
    box on;
    set(gca, 'LineWidth', 1.5);
    
    % ADD Stats INFOS
    text(0.02, 0.98, sprintf('n_{MPB} = %d\nn_{MPI} = %d', length(MPB_indices), length(MPI_indices)), ...
        'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'BackgroundColor', 'white', 'EdgeColor', 'k', 'FontSize', 10);
    
    %% PART 5: RATIOS GRAPHS (GRAPHIQUE SÉPARÉ)
    fprintf('\n--- RATIOS Graphs Generation ---\n');
    
    figure('Name', 'Ratios MPB/MPI', 'Position', [150, 150, 800, 500]);
    
    ratios = MPB_means ./ MPI_means;
    bar(x, ratios, 'FaceColor', [0.3 0.7 0.4], 'EdgeColor', 'k', 'LineWidth', 1.5);
    hold on;
    plot([0.5, n_props+0.5], [1, 1], 'r--', 'LineWidth', 3);
    
    set(gca, 'XTick', x, 'XTickLabel', prop_names, 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Ratio MPB/MPI', 'FontSize', 14, 'FontWeight', 'bold');
    title('Ratio of Mean values MPB/MPI', 'FontSize', 16, 'FontWeight', 'bold');
    grid on;
    grid minor;
    box on;
    set(gca, 'LineWidth', 1.5);
    
    % ADD Values on Bars 
    for i = 1:length(ratios)
        text(i, ratios(i) + 0.02, sprintf('%.2f', ratios(i)), ...
            'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
    end
    
    %% PART 6: PERCENTAGE DIFFERENCE GRAPH (SEPARATE GRAPH)
    fprintf('\n--- GENERATION OF GRAPHS ---\n');
    
    figure('Name', 'Difference MPB vs MPI (%)', 'Position', [200, 200, 800, 500]);
    
    diff_percent = (MPB_means - MPI_means) ./ MPI_means * 100;
    
    % Fix Colors
    colors = zeros(length(diff_percent), 3);
    for i = 1:length(diff_percent)
        if diff_percent(i) > 0
            colors(i, :) = [0.8 0.3 0.3]; % Red for Positif
        else
            colors(i, :) = [0.3 0.3 0.8]; % Bleu for Negatif
        end
    end
    
    for i = 1:length(diff_percent)
        bar(i, diff_percent(i), 'FaceColor', colors(i, :), 'EdgeColor', 'k', 'LineWidth', 1.5);
        hold on;
    end
    
    plot([0.5, n_props+0.5], [0, 0], 'k--', 'LineWidth', 2);
    
    set(gca, 'XTick', x, 'XTickLabel', prop_names, 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Difference [%]', 'FontSize', 14, 'FontWeight', 'bold');
    title('Relative Difference MPB vs MPI', 'FontSize', 16, 'FontWeight', 'bold');
    grid on;
    grid minor;
    box on;
    set(gca, 'LineWidth', 1.5);
    
    % Add the values to the bars
    for i = 1:length(diff_percent)
        if diff_percent(i) > 0
            text(i, diff_percent(i) + 1, sprintf('%.1f%%', diff_percent(i)), ...
                'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
        else
            text(i, diff_percent(i) - 1, sprintf('%.1f%%', diff_percent(i)), ...
                'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
        end
    end
    
    %% PART 7: LOCATION GRAPHS (SEPARATE GRAPHS)
    fprintf('\n--- GENERATION OF LOCATION MAPS ---\n');
    
    for prop_idx = 1:length(prop_names)
        prop = prop_names{prop_idx};
        
        figure('Name', sprintf('Localisation MPB/MPI - %s', prop), ...
               'Position', [250 + prop_idx*25, 250 + prop_idx*25, 800, 600]);
        
        % Heatmap Display
        imagesc(heatmap_data.(prop).x_grid, heatmap_data.(prop).y_grid, heatmap_data.(prop).Z);
        colormap(hot);
        c = colorbar;
        ylabel(c, prop, 'FontSize', 12, 'FontWeight', 'bold');
        
        hold on;
        
        % MPB Points in Red
        if ~isempty(MPB_indices)
            plot(heatmap_data.(prop).x_pos(MPB_indices), heatmap_data.(prop).y_pos(MPB_indices), ...
                'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r', 'LineWidth', 2);
        end
        
        % MPI Points in Blue (sampling to avoid overload)
        if length(MPI_indices) > 50
            sample_MPI = MPI_indices(1:round(length(MPI_indices)/50):end);
        else
            sample_MPI = MPI_indices;
        end
        plot(heatmap_data.(prop).x_pos(sample_MPI), heatmap_data.(prop).y_pos(sample_MPI), ...
            'bo', 'MarkerSize', 6, 'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'b');
        
        axis equal tight;
        xlabel('X [µm]', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel('Y [µm]', 'FontSize', 12, 'FontWeight', 'bold');
        title(sprintf('Localisation MPB/MPI - %s', prop), 'FontSize', 14, 'FontWeight', 'bold');
        set(gca, 'YDir', 'normal', 'FontSize', 11);
        
        % Legend and Stats
        legend({'', 'MPB (Contours)', 'MPI (Interior)'}, 'Location', 'best', 'FontSize', 11);
        
        text(0.02, 0.98, sprintf('MPB: %.2f±%.2f\nMPI: %.2f±%.2f\nDiff: %.1f%%', ...
            results.(prop).MPB_mean, results.(prop).MPB_std, ...
            results.(prop).MPI_mean, results.(prop).MPI_std, ...
            results.(prop).diff_percent), ...
            'Units', 'normalized', 'VerticalAlignment', 'top', ...
            'BackgroundColor', 'white', 'EdgeColor', 'k', 'FontSize', 10);
    end
    
    %% PART 8: Summary And Save
    fprintf('\n--- Summary Generation ---\n');
    
    % Creation of Output File 
    output_folder = sprintf('Analyse_MPB_MPI_%s_%s', sample_names{sample_idx}, datestr(now, 'yyyymmdd_HHMMSS'));
    mkdir(output_folder);
    
    % Save all Figures
    figs = findall(0, 'Type', 'figure');
    for i = 1:length(figs)
        fig_name = get(figs(i), 'Name');
        if ~isempty(fig_name)
            safe_name = regexprep(fig_name, '[^\w\s-]', '');
            safe_name = regexprep(safe_name, '\s+', '_');
            saveas(figs(i), fullfile(output_folder, [safe_name '.png']));
            saveas(figs(i), fullfile(output_folder, [safe_name '.fig']));
        end
    end
    
    % Save Data
    save(fullfile(output_folder, 'results_MPB_MPI.mat'), 'results', 'heatmap_data', 'MPB_indices', 'MPI_indices');
    
    % Detailed Text Report 
    report_file = fullfile(output_folder, 'Report_MPB_MPI.txt');
    fid = fopen(report_file, 'w');
    if fid ~= -1
        fprintf(fid, 'Summary MPB/MPI \n');
        fprintf(fid, '=====================================\n\n');
        fprintf(fid, 'Date: %s\n', datestr(now));
        fprintf(fid, 'Sample: %s\n\n', sample_names{sample_idx});
        
        fprintf(fid, 'CONFIGURATION:\n');
        fprintf(fid, '- Indent Size: %d µm\n', indent_size_um);
        fprintf(fid, '- Spacing: %d µm\n', spacing_um);
        fprintf(fid, '- Reference Propreties: %s\n\n', hvit_prop);
        
        fprintf(fid, 'SELECTION:\n');
        fprintf(fid, '- Selected MPB Points: %d\n', length(MPB_indices));
        fprintf(fid, '- Selected MPI Points Automatically: %d\n\n', length(MPI_indices));
        
        fprintf(fid, 'Results:\n');
        fprintf(fid, '%-10s %-15s %-15s %-8s %-8s %-8s %-8s\n', ...
            'Propriété', 'MPB (µ±σ)', 'MPI (µ±σ)', 'Ratio', 'Diff%', 'p-value', 'Signif');
        fprintf(fid, '%s\n', repmat('-', 1, 90));
        
        for i = 1:length(prop_names)
            prop = prop_names{i};
            fprintf(fid, '%-10s %-15s %-15s %-8.3f %-8.1f %-8.4f %-8s\n', ...
                prop, ...
                sprintf('%.2f±%.2f', results.(prop).MPB_mean, results.(prop).MPB_std), ...
                sprintf('%.2f±%.2f', results.(prop).MPI_mean, results.(prop).MPI_std), ...
                results.(prop).ratio, ...
                results.(prop).diff_percent, ...
                results.(prop).pvalue, ...
                iff(results.(prop).significant, 'YES', 'NO'));
        end
        
        fprintf(fid, '\nSignif: p < 0.05 (Significant Difference)\n');
        
        fprintf(fid, '\nGraphs:\n');
        fprintf(fid, '- Heatmaps For Each Property\n');
        fprintf(fid, '- Graphs of selected MPB on %s\n', hvit_prop);
        fprintf(fid, '- Comparison graph MPB vs MPI\n');
        fprintf(fid, '- Graph Ratios of MPB/MPI\n');
        fprintf(fid, '- Graph of the Difference in percentage \n');
        fprintf(fid, '- Localisation chartt for each proprety\n');
        
        fclose(fid);
    end
    
    fprintf('Done!\n');
    fprintf('Results Saved in: %s\n', output_folder);
    fprintf('Total Number of generated graphs: %d\n', length(figs));
    
    % Final Results 
    fprintf('\n=== Final Results ===\n');
    fprintf('Selected Points: %d MPB, %d MPI\n', length(MPB_indices), length(MPI_indices));
    fprintf('Analysed Propreties: %d\n', length(prop_names));
    
    significant_props = {};
    for i = 1:length(prop_names)
        if results.(prop_names{i}).significant
            significant_props{end+1} = prop_names{i};
        end
    end
    
    if ~isempty(significant_props)
        fprintf('Significant Difference: %s\n', strjoin(significant_props, ', '));
    else
        fprintf('No difference detected\n');
    end
    
    fprintf('\nGraphiques générés:\n');
    fprintf('- %d heatmaps individuelles\n', length(prop_names));
    fprintf('- 1 graphique de sélection\n');
    fprintf('- 1 graphique comparatif principal\n');
    fprintf('- 1 graphique des ratios\n');
    fprintf('- 1 graphique des différences\n');
    fprintf('- %d cartes de localisation\n', length(prop_names));
    fprintf('TOTAL: %d graphiques séparés\n', 4 + 2*length(prop_names));
end

% Fonction utilitaire pour les conditions
function result = iff(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end

%% UTILISATION
 analyze_melt_pool_boundaries_optimized(data_clean, sample_names, properties);