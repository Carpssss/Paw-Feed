FROM rocker/shiny:latest

# 1. Added libsodium-dev here
RUN apt-get update && apt-get install -y \
    libssl-dev \
    libmysqlclient-dev \
    libsodium-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Re-install packages
RUN R -e "install.packages(c('shiny', 'shinyjs', 'DBI', 'RMariaDB', 'pool', 'sodium'), repos='https://cran.rstudio.com/')"
# 3. Clean, Copy, and Set Permissions
RUN rm -rf /srv/shiny-server/*
COPY . /srv/shiny-server/
RUN chown -R shiny:shiny /srv/shiny-server/
USER shiny
EXPOSE 3838
CMD ["/usr/bin/shiny-server"]
