#create all the dashboards
library(flexdashboard)
library(maptools)
library(tidyverse)
library(purrr)
library(leaflet)
library(plotly)
library(lipdR)
library(dygraphs)
library(geoChronR)
library(here)
# Must have reticulate package to run python script that inserts javascript into html files.
library(reticulate)
source(here("functions.R"))

#prepare LiPD data..

project <- "PAGES2kv2"
lipdDir <- "~/Dropbox/LiPD/PAGES2k/Temp_v2_1_0/"

setwd(lipdDir)
zip(here("html",str_c(project,".zip")),files = list.files(lipdDir,pattern= "*.lpd"))

D <- readLipd(lipdDir)
TS <- extractTs(D)
setwd(here())



save(list = c("D","TS"),file = "temp.Rdata")

#remove columns we don't want to plot
varNames <- sapply(TS, "[[","paleoData_variableName")

good <- which(!(varNames %in% c("year","depth","age")))
TS <- TS[good]


#All datasets
dsn <- sapply(TS,"[[","dataSetName")
ui <- which(!duplicated(dsn))
udsn <- dsn[ui]
lat <- sapply(TS,"[[","geo_latitude")[ui]
lon <- sapply(TS,"[[","geo_longitude")[ui]
elev <- sapply(TS,"[[","geo_elevation")[ui]
archiveType <- sapply(TS,"[[","archiveType")[ui]
link <- paste0(udsn,".html") %>% 
  str_replace_all("'","_")


if(is.list(elev)){
  ge <- which(!sapply(elev,is.null))
  ne <- rep(NA,length(elev))
  ne[ge] <- as.numeric(unlist(elev))
  elev <- ge
}

#Organize metadata for map
map.meta <- data.frame(dataSetName = udsn, #datasetname
                       lat = lat,#lat
                       lon = lon,#lon
                      # elev = elev,#elevation
                       archiveType = factor(archiveType),#archiveType
                       link = link)#Link

#make project Rmd
createProjectRmd(project = project)
rmarkdown::render(here("html",str_c(project,".Rmd")))
failed = c()
for(i in 1:nrow(map.meta)){
  print(i)
  fname <- str_replace_all(udsn[i],"'","_")
  if(!file.exists(here("html",str_c(fname,".html")))){
    
    #thisTS <- filterTs(TS, str_c("dataSetName == ",udsn[i]))
    thisTS <- TS[which(udsn[i] == dsn)]
    test = try(createDashboardRmd(thisTS = thisTS,i = i))
    Sys.sleep(1)
    test = try(rmarkdown::render(here("html",str_c(fname,".Rmd"))))
    #writeLipd(D[[thisTS[[1]]$dataSetName]],path = here("html"))
    if(grepl(class(test),"try-error")){
      failed = c(failed, udsn[i])
    }
  }
}

# To run the python script, you need python 3.5+ with the BeautifulSoup4 module
# pip install beautifulsoup4
# You may use a conda environment with the package, or link the path to your system python
# use_python("/somepath/to/system/python")
use_virtualenv("your_conda_env_name_here")
py_run_file("add_page_stats.py")