FROM rocker/shiny:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libssl-dev \
    libmysqlclient-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c('shiny', 'shinyjs', 'DBI', 'RMySQL', 'pool', 'sodium'), repos='https://cran.rstudio.com/')"

# 1. Remove the default welcome page
RUN rm -rf /srv/shiny-server/*

# 2. Copy your files into the root of the shiny-server directory
COPY . /srv/shiny-server/

# 3. Ensure permissions are correct
RUN chown -R shiny:shiny /srv/shiny-server/

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]
