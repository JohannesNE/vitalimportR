# vitalimportR

Import data from [Vital Recorder](https://vitaldb.net/vital-recorder/).

[Vital Recorder](https://vitaldb.net/vital-recorder/) is a free software application, that allows easy recording of data from a number of medical devices.

This R package aims to ease importing this data into R, after it has been conveted to CSV files using a
utility function provided by the VitalRecorder authors.

> ⚠️ **Warning:** There may be a drift in time between records. `vital_s3.exe` exports only samples, starttime, sample rate and endtime. Evenly spacing samples between starttime and endtime should create a signal close to the recorded signal, but apparently, it does not. **It is recommended to save the vital record as .edf instead.**

## Install

If devtools is not already installed: `install.packages('devtools')`

``` r
devtools::install_github('JohannesNE/vitalimportR')
```

## Use

Convert your .vital file using vital_s3.exe.

From the command line:

``` cmd
cd <path-to-vitalrecorder-folder>/utilities
vital_s3.exe <input.vital> <output-folder>
```

Then from R:

``` r
vital_data <- read_vital(<output-folder>, tz = 'UTC')
```

``` r
> vital_data$Intellivue$ABP
# A tibble: 4,455 x 2
   time                  ABP
   <dttm>              <dbl>
 1 2019-07-11 11:54:25  79.8
 2 2019-07-11 11:54:25  79.1
 3 2019-07-11 11:54:25  78.5
 4 2019-07-11 11:54:25  78  
 5 2019-07-11 11:54:25  77.5
 6 2019-07-11 11:54:25  77.1
 7 2019-07-11 11:54:25  76.6
 8 2019-07-11 11:54:25  76.2
 9 2019-07-11 11:54:25  75.8
10 2019-07-11 11:54:25  75.4
# … with 4,445 more rows
```

### Linux

vital_s3.exe runs with [wine](https://www.winehq.org/)
