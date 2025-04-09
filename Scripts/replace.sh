#!/usr/bin/env sh

set -a
. ./Scripts/variables.sh
set +a

################################################################################
## Variables
################################################################################

# Get current date in format DD.MM.YYYY
document_date=$(date +%d.%m.%Y)

# Get latest git tag
document_git_tag=$(git describe --tags --abbrev=0)


################################################################################
## Environment specific replacements commands
################################################################################

if [ $CI ]; then
	sedcmd="sed -i"
else
	sedcmd="sed -i ''"
fi


################################################################################
## REPLACERS
################################################################################

# Add pagebreak before each H1 element
$sedcmd 's/^# /\n\\newpage\n\n# /g' $1
# Document date
$sedcmd "s/REPLACE_DATE/$document_date/g" $1
# Document version
$sedcmd "s/REPLACE_VERSION/v$CI_COMMIT_REF_NAME/g" $1
# Replace path to images
$sedcmd 's/Media\//Temp\/Media\//g' $1

# Replace DOCUMENT_NAME and escape spaces
$sedcmd "s/REPLACE_DOCUMENT_NAME/$(echo $DOCUMENT_NAME | sed 's/ /\\ /g')/g" $1
# Replace DOCUMENT_NAME_SHORT
$sedcmd "s/REPLACE_DOCUMENT_NAME_SHORT/$DOCUMENT_NAME_SHORT/g" $1
# Replace DOCUMENT_SUBBJECT
$sedcmd "s/REPLACE_DOCUMENT_SUBJECT/$DOCUMENT_SUBJECT/g" $1
# Replace DOCUMENT_TITLE
$sedcmd "s/REPLACE_DOCUMENT_TITLE/$DOCUMENT_TITLE/g" $1
# Replace DOCUMENT_FILENAME
$sedcmd "s/REPLACE_DOCUMENT_FILENAME/$DOCUMENT_FILENAME/g" $1
# Replace DOCUMENT_EMAIL
$sedcmd "s/REPLACE_DOCUMENT_EMAIL/$DOCUMENT_EMAIL/g" $1
# Replace PRICE_EXTRA_HOUR
$sedcmd "s/REPLACE_PRICE_EXTRA_HOUR/$PRICE_EXTRA_HOUR/g" $1
# Replace PRICE_MONTHLY
$sedcmd "s/REPLACE_PRICE_MONTHLY/$PRICE_MONTHLY/g" $1
# Replace PRICE_ONCE
$sedcmd "s/REPLACE_PRICE_ONCE/$PRICE_ONCE/g" $1
# Replace PERIOD_CANCEL
$sedcmd "s/REPLACE_PERIOD_CANCEL/$PERIOD_CANCEL/g" $1
# Replace PERIOD_LENGTH_MIN
$sedcmd "s/REPLACE_PERIOD_LENGTH_MIN/$PERIOD_LENGTH_MIN/g" $1
# Replace PERIOD_REPEAT
$sedcmd "s/REPLACE_PERIOD_REPEAT/$PERIOD_REPEAT/g" $1

success "Replaced characters in file \"$1\"."

# Remove temporary file
rm "$1''"
