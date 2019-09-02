satrd <- read.csv("docs/data/satrdays.csv", header = TRUE)

satrd_cal <-  satrd[c("Event", "Date", "URL", "Additional_Info", "Owner")]
colnames(satrd_cal) <- c("title","start", "url", "additional_info", "owner")
satrday_json <- jsonlite::toJSON(satrd_cal, pretty = TRUE )
writeLines(satrday_json, "docs/data/satrdays.json")
