context("Read Vital data")
library(vitalrecordR)

test_path <- system.file('extdata','test_data_demo', package = 'vitalrecordR')

test_rec_nest <- read_vital(test_path, tz = 'CET')
test_rec_unnest <- read_vital(test_path, tz = 'CET', nested_list = FALSE)

test_that("imported header has the right size", {
    test_header <- read_vital_header(test_path, tz = 'UTC')
    expect_equal(nrow(test_header), 18)
    expect_equal(length(test_header), 15)
})

test_that("read_vital imports all signals", {
    expect_equal(length(test_rec_nest$tracks), 2)
    expect_equal(length(test_rec_unnest$tracks), 18)
    expect_equal(length(test_rec_nest$tracks$Intellivue$ABP$ABP), 4455)
    mean_pleth <- mean(test_rec_nest$tracks$Intellivue$PLETH$PLETH)
    expect_gt(mean_pleth, 50.4)
    expect_lt(mean_pleth, 50.5)
})

test_that("signals has correct attributes", {
    # Unit
    expect_equal(unname(sapply(test_rec_unnest$tracks, attr, 'vital.unit')),
                 test_rec_unnest$header$unit[order(test_rec_unnest$header$track)])
    # Sample Rate
    expect_equal(unname(sapply(test_rec_unnest$tracks, attr, 'vital.samplerate')),
                 test_rec_unnest$header$sample_rate[order(test_rec_unnest$header$track)])
})
