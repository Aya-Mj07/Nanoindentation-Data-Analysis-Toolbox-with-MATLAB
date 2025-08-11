[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[![MATLAB](https://img.shields.io/badge/MATLAB-R2018b%2B-blue.svg)](https://www.mathworks.com/products/matlab.html)

### Nanoindentation Data Analysis Toolbox with MATLAB
**I.	Project Description :**

This MATLAB toolbox provides comprehensive analysis and visualization tools for nanoindentation data, specifically designed for materials characterization. It handles multiple data files of varying sizes and automatically generates standardized heatmaps, statistical analyses, and comparative visualizations.

**II.	Key Features :**

•	Multi-file Processing: Handles any number of input files with different data sizes 

•	Adaptive Heatmap Generation: Creates standardized heatmaps for easy comparison 

•	Statistical Analysis: Comprehensive statistical comparison between samples 

•	Data Cleaning: Intelligent filtering based on material properties 

•	Flexible Visualization: Multiple visualization options including scatter plots, boxplots, and heatmaps

**III.	Code Structure and Explanation :**
1.	Main Configuration Section:
   
`properties = {'HVIT', 'HIT', 'EIT'}; % Properties to analyze`

•	HVIT: Vickers Hardness from Indentation Test

•	HIT: Hardness from Indentation Test (GPa)

•	EIT: Elastic Modulus from Indentation Test (GPa)

2.	 File Selection and Management :

The code allows users to:

•	Select multiple files at once 
`[filenames, pathname] = uigetfile('*.txt', 'Sélectionnez les fichiers', 'MultiSelect', 'on');
`

•	Name each sample individually

•	Handle any number of files dynamically

3.	Data Reading and Parsing :

The parser:

•	Reads tab-delimited text files

•	Converts European decimal format (comma) to standard (dot)

•	Extracts spatial coordinates (x, y) and mechanical properties


4.	Data Cleaning :

Cleaning criteria are optimized for AlSi20 alloy properties:

•	Removes outliers based on physical limits

•	Filters NaN and infinite values

•	Preserves data integrity

```
% Criteria specific for AlSi20 (Aluminum + 20% Silicon)
if strcmp(prop, 'HVIT')
    valid = values > 50 & values < 350 & ~isnan(values);
elseif strcmp(prop, 'HIT')
    valid = values > 0.3 & values < 5 & ~isnan(values);
elseif strcmp(prop, 'EIT')
    valid = values > 40 & values < 150 & ~isnan(values);
end

```
5.	Standardized Heatmap Generation :
 
The standardization process:

•	Finds the smallest dataset

•	Sets a common grid size for all heatmaps

•	Ensures visual consistency across samples.

```
% Find the file with minimum points
min_points = inf;
for i = 1:num_files
    current_points = data_info(i).num_points_clean;
    if current_points < min_points
        min_points = current_points;
    end
end

% Determine common heatmap size
if min_points >= 625
    common_heatmap_size = 25;  % 25×25 grid
elseif min_points >= 400
    common_heatmap_size = 20;  % 20×20 grid
% ... continues for other sizes
```

6.	 Spatial Interpolation :

Adaptive interpolation strategy:

•	**Cubic: For dense data (>70% grid coverage)**

•	Linear: For moderate density (30-70%)

•	Nearest: For sparse data (<30%)

```
% Interpolation based on data density
if length(values) >= hmap_size_x * hmap_size_y * 0.7
    Z = griddata(x_pos, y_pos, values, X_grid, Y_grid, 'cubic');
elseif length(values) >= hmap_size_x * hmap_size_y * 0.3
    Z = griddata(x_pos, y_pos, values, X_grid, Y_grid, 'linear');
else
    Z = griddata(x_pos, y_pos, values, X_grid, Y_grid, 'nearest');
End
```

7.	 Uniform Axis Scaling :
   
Ensures all heatmaps have:

•	Identical spatial scales

•	Same aspect ratio

•	Comparable visual representation

9.	 Statistical Analysis :

Provides:

•	Mean, median, standard deviation

•	Coefficient of variation (homogeneity measure)

•	Comparative bar charts and boxplots

10.	Visualization Options :

The toolbox generates multiple figure types:

•	Heatmaps: Color-coded property distribution

•	Scatter plots: Individual measurement points

•	Statistical plots: Boxplots, histograms, bar charts

•	Comparison plots: Side-by-side analysis

11.	 Automatic Export :

Saves:

•	PNG for presentations

•	FIG for further MATLAB editing

•	PDF for publications

•	MAT file with all processed data

**IV.	Usage Instructions**

1.	Prepare your data files: Ensure they are tab-delimited text files with the expected format.This is the used Format in my code :
                                                 **Measurement_ID | EIT | HIT | HVIT | hmax | X_pos | Y_pos**
2.	Run the main Matlab function: 
**analyze_nanoindentation_data**

3.	Select files: Choose all files you want to analyze

4.	Name samples: Provide meaningful names for each dataset
   
5.	Review results: Check the generated figures and statistics
   
**V.	Data Format Requirements**

Input files should contain tab-separated columns:

1.	EIT (Elastic Modulus) [GPa]
  
2.	HIT (Hardness) [GPa]
  
3.	HVIT (Vickers Hardness) [HV]
   
4.	hmax (Maximum depth) [µm]

5.	X position [mm]
    
6.	Y position [mm]
   
**VI.	Output Structure:**


> Resultats_Analyse_YYYYMMDD_HHMMSS/

> ├── Heatmaps_HVIT_standardized.png
> 
> ├── Heatmaps_HIT_standardized.png
> 
> ├── Heatmaps_EIT_standardized.png
> 
> ├── Scatter_plots_all_properties.png
> 
> ├── Statistical_comparison.png
> 
> ├── donnees_analysees.mat
> 
> └── rapport_analyse.txt

**VII.	 Customization Options**

1.	Modify cleaning criteria:
matlab

```
% In the data cleaning section, adjust thresholds:
if strcmp(prop, 'HVIT')
    valid = values > YOUR_MIN & values < YOUR_MAX & ~isnan(values);
end
```

2.	Change heatmap size thresholds:

matlab
```
% Modify the size determination logic:
if min_points >= YOUR_THRESHOLD
    common_heatmap_size = YOUR_SIZE;
end
```

**VIII.	Applications**

This toolbox is ideal for:

•	Material science research

•	Quality control in manufacturing

•	Comparative studies of surface treatments

•	Mechanical property mapping

•	Academic research in nanoindentation

**IX.	Requirements**

•	MATLAB R2024 or later

•	Statistics and Machine Learning Toolbox (for boxplot)

•	No additional toolboxes required for basic functionality

**X.	Contributing**

Feel free to contribute by:

•	Adding new visualization types

•	Implementing additional statistical analyses

•	Supporting new file formats

•	Improving the user interface

**_Contact_**

> For questions or support, please open an issue on the GitHub repository.
> 
>  Or Send Email To : eyamajdoub53@gmail.com
> 
> Or Contact Me on [LinkedIn:](https://www.linkedin.com/in/aya-majdoub-b24346352/)

________________________________________

**> Note: This toolbox was specifically developed for AlSi20 alloy characterization but can be adapted for other materials by modifying the cleaning criteria.**

**> All my data was extracted from the indentation Software , after a Nano-Hardness Test of my Sample , The used machine is the ANTON PAAR [NHT³](https://www.fourni-labo.fr/produit/nht3) .**





