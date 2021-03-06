#' Read Header CSV from S3 export
#'
#' @param path Path to folder containing the files exported by utilities/vital_s3.exe
#' @param tz Timezone used for converting Unix epochs to datetime.
#' @importFrom rlang .data
#' @export
read_vital_header <- function(path, tz) {
    stopifnot(length(path) == 1)

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
                                  'starttime_epoch',
                                  'endtime_epoch',
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
                        starttime_epoch = readr::col_double(),
                        endtime_epoch = readr::col_double(),
                        sample_rate = readr::col_double(),
                        x6 = readr::col_double(),
                        gain = readr::col_double(),
                        offset = readr::col_double()
                    )
    )
    res <- dplyr::mutate(res, starttime = as.POSIXct(.data$starttime_epoch, origin="1970-01-01", tz = tz),
                   endtime = as.POSIXct(.data$endtime_epoch, origin="1970-01-01", tz = tz))

    res <- tidyr::separate(res, .data$track, into = c('device', 'track'), sep = '/')

    dplyr::select(res, - dplyr::starts_with('x'))
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

    dplyr::mutate(res, time = as.POSIXct(.data$time, origin="1970-01-01", tz = tz))
}

# read file of type EVENT
read_vital_event <- function(path, track, tz) {
    res <- readr::read_csv(path, col_names = c('time', track),
                           col_types = readr::cols(
                               readr::col_double(),
                               readr::col_character()
                           ))

    dplyr::mutate(res, time = as.POSIXct(.data$time, origin="1970-01-01", tz = tz))
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
#' @param nested_list Create a nested list of tracks inside a list of devices.
#' Necessary to deal with duplicate track names between devices.
#' @param tracks_only Do not include header in returned list.
#' If FALSE, an error is given if there are any duplicate track names.
#' @return A (nested) list of tracks.
#' @examples
#' test_folder <- system.file('extdata', 'test_data_demo', package = 'vitalimportR')
#' read_vital(test_folder, tz = 'CET')
#' @importFrom rlang .data
#' @export
read_vital <- function(path, tz = 'UTC', nested_list = TRUE, tracks_only = FALSE) {
    header <- read_vital_header(path, tz = tz)

    # Give a name to the EVENT 'device'
    header$device[header$track == 'EVENT'] <- 'VITAL'

    select_vital_loader <- function(row) {
        if (row$track_type == 'N') {
            res <- read_vital_numeric(path = paste0(path, '/', row$file, '.csv.gz'),
                                      track = row$track,
                                      tz = tz)
        }

        if (row$track_type == 'W') {
            res <- read_vital_wave(path = paste0(path, '/', row$file, '.csv.gz'),
                                   track = row$track,
                                   starttime_e = row$starttime_epoch,
                                   endtime_e = row$endtime_epoch,
                                   sample_rate = row$sample_rate,
                                   gain = row$gain,
                                   offset = row$offset,
                                   tz = tz)
        }

        if (row$track_type == 'S') {
            res <- read_vital_event(paste0(path, '/', row$file, '.csv.gz'),
                                    track = row$track,
                                    tz = tz)
        }

        attr(res, 'signal.unit') <- row$unit
        attr(res, 'signal.samplerate') <- row$sample_rate

        res

    }

    if (nested_list) {

        # Split dataframe into a nested list of tracks inside device
        header_list_device <- split(header, header$device)
        header_list_device_track <- lapply(header_list_device, function(x) split(x, x$track))

        # Nested lapply, to apply select_vital_loader to second layer (tracks)
        tracks <- lapply(header_list_device_track, lapply, select_vital_loader)
    }

    else {
        stopifnot(!anyDuplicated(header$track))

        header_list_track <- split(header, header$track)
        tracks <- lapply(header_list_track, select_vital_loader)

    }

    if (tracks_only) return(tracks)

    list(header = header, tracks = tracks)
}
