
FROM rocker/shiny:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libssl-dev \
    libpq-dev \
    libsodium-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c('shiny', 'shinyjs', 'DBI', 'RPostgres', 'pool', 'sodium'), repos='https://cran.rstudio.com/')"

# Clean default Shiny server content
RUN rm -rf /srv/shiny-server/*

# Copy application files
COPY . /srv/shiny-server/

# Set ownership
RUN chown -R shiny:shiny /srv/shiny-server/

# Create log directory
RUN mkdir -p /var/log/shiny-server && chown -R shiny:shiny /var/log/shiny-server

# Switch to shiny user
USER shiny

# Expose port
EXPOSE 3838

# Start Shiny Server
CMD ["/usr/bin/shiny-server"]
