#' Read Header CSV from S3 export
#'
#' @param path Path to folder containing the files exported by utilities/vital_s3.exe
#' @param tz Timezone used for converting Unix epochs to datetime.
#' @export
read_vital_header <- function(path, tz) {
    res <- readr::read_csv(paste0(path, '/trks.csv'),
                    col_names = c('file',
                                  'record_name',
                                  'track',
                                  'unit',
                                  'minval',
                                  'maxval',
                                  'x3', #unknown
                                  'x4', #unknown
                                  'x5', #unknown
                                  'track_type',
                                  'starttime',
                                  'endtime',
                                  'sample_rate',
                                  'x6', #unknown
                                  'gain',
                                  'offset'
                    ),
                    col_types = readr::cols(
                        file = readr::col_character(),
                        record_name = readr::col_character(),
                        track = readr::col_character(),
                        unit = readr::col_character(),
                        minval = readr::col_double(),
                        maxval = readr::col_double(),
                        x3 = readr::col_double(),
                        x4 = readr::col_double(),
                        x5 = readr::col_double(),
                        track_type = readr::col_character(),
                        starttime = readr::col_double(),
                        endtime = readr::col_double(),
                        sample_rate = readr::col_double(),
                        x6 = readr::col_double(),
                        gain = readr::col_double(),
                        offset = readr::col_double()
                    )
    )
    res <- dplyr::mutate(res, starttime_epoch = starttime,
                  endtime_epoch = endtime)
    res <- dplyr::mutate(res, starttime = as.POSIXct(starttime, origin="1970-01-01", tz = tz),
                   endtime = as.POSIXct(endtime, origin="1970-01-01", tz = tz))

    res <- tidyr::separate(res, track, into = c('device', 'track'), sep = '/')

    within(res, rm(x3, x4, x5, x6))
}

# read file of type wave
read_vital_wave <- function(path, track, starttime_e, endtime_e, sample_rate, gain, offset,
                            tz, to_dataframe = TRUE) {
    res <- readr::read_csv(path, col_names = track,
                           col_types = readr::cols(
                               readr::col_double()
                           ))

    # Convert to physical unit
    res[[1]] <- res[[1]] * gain + offset

    corrected_sample_rate <- nrow(res) / (endtime_e - starttime_e)

    message(sprintf('Importing %s with sample rate: %.2f. Nominal sample rate: %.2f',
                    track,
                    corrected_sample_rate,
                    sample_rate))

    # Give warning if corrected sample rate is more than 2% different from the nominal sample rate
    if (abs((corrected_sample_rate - sample_rate) / sample_rate) > 0.02) {
        warning(sprintf('Corrected sample rate is %.2f %% from nominal sample rate',
                        100 * (corrected_sample_rate - sample_rate) / sample_rate))
    }


    if (to_dataframe) {
        time_df <- dplyr::tibble(time = as.POSIXct(seq(starttime_e, to = endtime_e, length.out = nrow(res)),
                                                   origin="1970-01-01", tz = tz))
        dplyr::bind_cols(time_df, res)
    } else {
        res[[1]]
    }
}

# read file of type numeric
read_vital_numeric <- function(path, track, tz) {
    res <- readr::read_csv(path, col_names = c('time', track),
                    col_types = readr::cols(
                        readr::col_double(),
                        readr::col_double()
                    ))

    dplyr::mutate(res, time = as.POSIXct(time, origin="1970-01-01", tz = tz))
}

# read file of type EVENT
read_vital_event <- function(path, track, tz) {
    res <- readr::read_csv(path, col_names = c('time', track),
                           col_types = readr::cols(
                               readr::col_double(),
                               readr::col_character()
                           ))

    dplyr::mutate(res, time = as.POSIXct(time, origin="1970-01-01", tz = tz))
}

#' Read Vital
#'
#' Loads a folder of gz compressed csv files, exported by the vital utility vital_s3.exe
#'
#' @details
#' Before import, a .vital file must be converted to csv files using the untility program vital_s3.exe.
#' This can be found in `<vitalrecorder-folder>/utilities`.
#'
#' From the command line:
#' `cd <path-to-vitalrecorder-folder>/utilities`
#' `vital_s3.exe <input.vital> <output-folder>`
#'
#' @param path Path to folder containing the files exported by utilities/vital_s3.exe
#' @param tz Timezone used for converting Unix epochs to datetime.
#' @return A (nested) list of tracks.
#' @examples
#' test_folder <- system.file('extdata', 'test_data_demo', package = 'vitalrecordR')
#' read_vital(test_folder, tz = 'CET')
#' @export
read_vital <- function(path, tz = 'UTC') {
    header <- read_vital_header(path, tz = tz)

    # Give a name to the EVENT 'device'
    header$device[header$track == 'EVENT'] <- 'VITAL'

    select_vital_loader <- function(row) {
        if (row$track_type == 'N') {
            return(read_vital_numeric(path = paste0(path, '/', row$file, '.csv.gz'),
                                      track = row$track,
                                      tz = tz))
        }

        if (row$track_type == 'W') {
            return(read_vital_wave(path = paste0(path, '/', row$file, '.csv.gz'),
                                   track = row$track,
                                   starttime_e = row$starttime_epoch,
                                   endtime_e = row$endtime_epoch,
                                   sample_rate = row$sample_rate,
                                   gain = row$gain,
                                   offset = row$offset,
                                   tz = tz))
        }

        if (row$track_type == 'S') {
            return(read_vital_event(paste0(path, '/', row$file, '.csv.gz'),
                                    track = row$track,
                                    tz = tz))
        }

    }

    # Split dataframe into a nested list of tracks inside device
    header_list_device <- split(header, header$device)
    header_list_device_track <- lapply(header_list_device, function(x) split(x, x$track))

    # Nested lapply, to apply select_vital_loader to second layer (tracks)
    lapply(header_list_device_track, lapply, select_vital_loader)
}
