#!/usr/bin/env sh

set -a
. ./Scripts/variables.sh
. ./.env
set +a

logo

# Build PDF files for each Markdown file in the content directory
# and place them in the output directory.
h1 "Generate PDF with combined content"


################################################################################
## Prepare
################################################################################

h2 "Prepare"


## Environment specific replacements commands
###############################################################################
if [ "$CI" ]; then
    sedcmd="sed -i"
else
    sedcmd="sed -i ''"
fi


## Requirement
################################################################################

# Check if Docker is installed
if ! [ -x "$(command -v docker)" ]; then
  error "Docker is not installed. Please install Docker!"
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  error "$alarm\tDocker is not running. Please start Docker!"
fi

# Check if sed is installed
if ! [ -x "$(command -v sed)" ]; then
  error "$alarm\tSed is not installed. Please install Sed!"
fi

success "Docker and Sed are installed and running."

# Pull docker image ghcr.io/vergissberlin/pandoc-eisvogel-de from GitHub Container Registry if it doesn't exist
if ! docker image inspect ghcr.io/vergissberlin/pandoc-eisvogel-de > /dev/null 2>&1; then
    info "Pull docker image ghcr.io/vergissberlin/pandoc-eisvogel-de from GitHub Container Registry"
    docker pull ghcr.io/vergissberlin/pandoc-eisvogel-de
    success "Docker image ghcr.io/vergissberlin/pandoc-eisvogel-de pulled from GitHub Container Registry"
fi

## Directories
################################################################################

if [ -d "Temp" ]; then
    warning "Temporary directory already exists. Deleting all files in it."
    rm -rf Temp
    success "Temporary deleted."
    mkdir -p Temp
    success "Temporary directory recreated."
else
    warning "Temporary directory does not exist. Creating it."
    mkdir -p Temp
    success "Temporary directory created."
fi


# Copy all configuration files from the template directory to the temporary directory
cp Template/Config/defaults.yml Temp/
cp Template/Config/metadata.yml Temp/
success "Configuration files copied to temporary directory."


# Remove Results directory if it exists
if [ -d "Results" ]; then
    info "Results directory already exists. Deleting all files in it."
    rm -rf Results/*
    success "Results directory deleted."
    info "Results directory does not exist. Creating it."
    mkdir -p Results
    success "Results directory recreated."
else
    info "Results directory does not exist. Creating it."
    mkdir -p Results
    success "Results directory created."
fi


################################################################################
## Content
################################################################################

h2  "Content"

# Combine all Markdown files
###############################################################################
cat Content/*.md > Temp/combined.md
success "Combined all Markdown files into a single Markdown file."

## Modifier
###############################################################################
sh Scripts/replace.sh Temp/combined.md



################################################################################
## Generate PDF
################################################################################

h2  "Generate PDF"

# Replace some variables in configuration files
###############################################################################
sh Scripts/replace.sh Temp/metadata.yml
sh Scripts/replace.sh Temp/defaults.yml

# Generate a single PDF file from all Markdown files in the content directory
###############################################################################
info "Generate PDF for all files"
if docker run -i -v "$PWD:/data" ghcr.io/vergissberlin/pandoc-eisvogel-de \
  -o "Results/${OFFER_FILENAME}-${document_git_tag}.pdf" \
  --defaults Template/Config/defaults.yml \
  --metadata-file Template/Config/metadata.yml \
  -V title="${OFFER_NUMBER}" \
  -V subtitle="${OFFER_NAME}" \
  -V subject="${OFFER_SUBJECT}" \
  -V lang="de" \
  -V author="${COMPANY_NAME_LONG}" \
  -V description="Angebot von ${OFFER_AUTHOR}" \
  -V footer-center="${OFFER_NUMBER} - v${document_git_tag}" \
  -V rights="© ${document_date_year} ${OFFER_NAME}, ${OFFER_LICENSE}, ${COMPANY_NAME_SHORT}" \
  -V date="v${document_git_tag}, ${document_date}" \
  Temp/combined.md; then
    success "PDF generated successfully."
else
    error "Failed to generate PDF."
fi


################################################################################
## Clean up
################################################################################

h2 "Clean up"

# Remove the temporary directory
rm -rf Temp
success "Temporary directory deleted."
