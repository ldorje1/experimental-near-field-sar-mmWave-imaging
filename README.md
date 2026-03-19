## Near-field SAR milli-wave imaging
This repository provides code for near-field millimeter-wave imaging based on an experimental measurement platform. The platform consists of a TI IWR1843BOOST radar sensor (76–81 GHz), a DCA1000 evaluation module for high-speed raw data capture and streaming, a two-axis mechanical scanning stage, a motion controller, and a host PC for measurement control, signal processing, and image generation.

***

### Our experimental test bed
<p align="center">
  <img src="figures/test_bed.png" alt="Experimental testbed" width="500">
</p>

*** 
### Example SAR Images
<p align="center">
  <img src="figures/sar_image_bandw.png" alt="SAR black and white image" width="400">
</p>

<p align="center">
  <img src="figures/sar_image_color.png" alt="SAR color image" width="400">
</p>

*** 

### SAR image reconstruction using classical and DNN based algorithms
<p align="center">
  <img src="figures/sar_image_diff_algo.png" alt="Different algorithm comparison" width="500">
</p>

### Generate sar images 
Run `generate_sar_image.m` to reconstruct a SAR image from the experimental raw data.  
choose:
1. the dataset name
2. the reconstruction algorithm
