[ ! -f .env ] || export $(grep -v '^#' .env | xargs)