# Low-Light Image Enhancement in MATLAB

This course project implements the SSIF and CLAHE method
proposed by Demir and Kaplan (2023).

## Files
- Master_Project.m: image selection, enhancement, NIQE evaluation
  and kappa parameter study.
- SSIF.m: the original released SSIF filter.
- LIME, NPE, Own and Provided: input image folders.

## Requirements
MATLAB with Image Processing Toolbox.

## How to run
1. Download and extract this repository.
2. Open the project folder in MATLAB.
3. Run Master_Project.m.
4. Choose an input folder and select one image or all images.

## Evaluation
The project compares the original image, an unofficial LIME
implementation, and SSIF + CLAHE using NIQE and visual inspection.
PSNR is not calculated because paired reference images are unavailable.

## Sources
Paper:
https://doi.org/10.1016/j.dsp.2023.104054

Original SSIF implementation:
https://github.com/nhk21/Low-light-image-enhancement-based-on-sharpening-smoothing-image-filter

The original algorithms belong to their respective authors.
My work adds the project workflow, comparisons and parameter study.
