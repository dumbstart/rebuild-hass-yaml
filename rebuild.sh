#!/usr/bin/env bash 
# set -o errexit
# set -o nounset
# set -ex

# Create file named entity_id.txt to save all the entity_ids found in your YAML
echo "# entity_id" > `pwd`/entity_id.txt
DIR=$(echo "`pwd`/$1")

# Create array of all domains in your YAML
declare -a DOMAINS
DOMAINS=("alert" "automation" "binary_sensor" "calendar" "camera" "climate" "customizer" "device_tracker" "group" "input_boolean" "input_number" "input_select" "input_text" "light" "media_player" "persistent_notification" "remote" "scene" "script" "sensor" "shell_command" "sun" "switch" "timer" "variable" "zone")

# Remove all old _created.yaml files
find "$DIR" -name "*_created.yaml" -type f -delete

# Create array of all files found in YAML directory
declare -a FOUND_FILES
FOUND_FILES=($(find $DIR -name "*.yaml" -type f -print))
echo "Cleaning up configuration files..."
for SPACING in ${FOUND_FILES[@]}; do
  sed -i '/^$/d' $SPACING # Remove blank lines
  sed -i $'s/^[a-zA-Z]/\\\n&/g' $SPACING # Add a blank line before each ITEM section
  sed -i '1{/^$/d}' $SPACING # Remove the first blank line
  FILENAME=$(echo $SPACING | cut -d '.' -f 1)
  FILENAME=$(echo $FILENAME"_created.yaml")
  echo "# $FILENAME" > $FILENAME
  echo " " >> $FILENAME
done
echo "Finding all entity_ids in YAML..."

# Search for all domains in all files in YAML directory
for ITEM in ${DOMAINS[@]}; do
#   Variable on whether to show or hide domain
  TITLE=false 
  for FILES in ${FOUND_FILES[@]}; do # Loop through all files and save 
    TEXT=$(cat $FILES > "`pwd`/rebuild_temp.txt")
    FOUND_DOMAIN=$(grep -n "^$ITEM" "`pwd`/rebuild_temp.txt" | cut -f1 -d: )
    FILENAME=$(echo $FILES | cut -d '.' -f 1)
    FILENAME=$(echo $FILENAME"_created.yaml")
    if [ -n "$FOUND_DOMAIN" ]; then
      # Output domain if it has not been shown yet
      [ "$TITLE" == false ] && printf "\n# %s\n" "$ITEM"; TITLE=true
      if [ "$FOUND_DOMAIN" -ne 0 ] && [ -n "$FOUND_DOMAIN" ]; then
        echo "Checking $FILENAME..."
        COUNT=0; BREAK=false
#         Read FILES to locate reference to ITEM
        while IFS='' read -r LINE || [[ -n "$LINE" ]]; do
          COUNT=$(($COUNT+1)); NUMBER=$FOUND_DOMAIN; NEXT=$(echo $LINE | sed -e 's/*:$//' )
          if [ -z "$LINE" ] || [ -z "$NEXT" ] && [ $COUNT -ge $NUMBER ]; then
            BREAK=true
          fi
#           Check to see if no more ITEM found in FILES
          if [ $COUNT -ge $NUMBER ] && [ $BREAK == false ]; then
            OUTPUT=$(echo $LINE | grep -v "^#")
            if [ -n "$OUTPUT" ]; then
#               Output to file
              echo "$LINE" >> $FILENAME
              LINE=$(echo $LINE | cut -d "#" -f 1 | grep -v "entity_id")
#               Adjust entity_id based on ITEM domain
              case "$ITEM" in
                sensor )
                  NAME=$(echo $LINE | grep ':$' | grep -v "$ITEM" | grep -v "sensors:" | grep -v "delay_off" | grep -v "options:" | tr -d ":")
                  ;;
                binary_sensor )
                  NAME=$(echo $LINE | grep ':$' | grep -v "$ITEM" | grep -v "sensors:" | grep -v "delay_off" | grep -v "options:" | tr -d ":")
                  ;;
                automation )
                  NAME=$(echo $LINE | grep 'alias' | cut -d ":" -f 2 | sed -e 's/^[[:space:]]//' | sed -e 's/[[:space:]]$//' | tr " " "_" | tr '[:upper:]' '[:lower:]')
                  ;;
                input_boolean )
                  NAME=$(echo $LINE | grep ':$' | grep -v "$ITEM" )
                  ;;
                timer )
                  NAME=$(echo "$LINE" | grep -vi "^timer:$" | grep ':$' |  cut -d ":" -f 1 | grep -v "duration")
                  ;;
                shell_command )
                  NAME=$(echo $LINE | grep ": " | grep -v "shell_command" | cut -d ":" -f 1 | grep -v "    " | grep -v "'" | grep -v '"' )
#                   NAME=$(echo $LINE | cut -d ":" -f 1 | grep -v "$ITEM")
                  ;;
                zone )
                  NAME=$(echo $LINE | grep 'name:' | tr -d '"' | cut -d ':' -f 2 | sed -e 's/^[[:space:]]*//' | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
                  ;;
                alert )
                  NAME=$(echo $LINE | grep ':$' | grep -v "$ITEM:" | grep -v "notifiers" )
                  ;;
                media_player )
                  NAME=$(echo $LINE | grep 'name:' | grep -v "$ITEM"  | cut -d ":" -f 2 | sed -e 's/^[[:space:]]*//' | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
                  ;;
                calendar )
                  NAME=$(echo $LINE | grep 'name:' | grep -v "$ITEM"  | cut -d ":" -f 2 | sed -e 's/^[[:space:]]*//' | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
                  ;;
                script )
                  NAME=$(echo $LINE | grep ':$' | grep -v "$ITEM" | grep -v "sequence" | grep -v "attachment" | grep -v "variables" | grep -v "data_template:$" | grep -v "-" | grep -v "command" | grep -v "packet" | grep -v "data:$")
                  ;;
                camera )
                  NAME=$(echo $LINE | grep 'name:' | cut -d ":" -f 2 | sed -e 's/^[[:space:]]//' | sed -e 's/^[[:space:]]*//' | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
                  ;;
                input_select )
                  NAME=$(echo $LINE | grep ':$' | grep -v "$ITEM" | grep -v "options")
                  ;;
                * )
                  NAME=$(echo $LINE | grep ':$' | grep -v "$ITEM" )
                  ;;
              esac
#               Check NAME to ensure it is not blank
              if [ -n "$NAME" ]; then
                NAME=$(echo $NAME | tr -d ":" )
                ENTITY=$(printf "%s.%s:\n" "$ITEM" "$NAME")
                printf "  %s.%s:\n" "$ITEM" "$NAME"
                echo $ENTITY >> "`pwd`/entity_id.txt"
              fi
            fi
          fi
        done < "`pwd`/rebuild_temp.txt"
      fi
    fi
  done
done
# Remove temp files
echo "Removing all temp files..."
for SPACING in ${FOUND_FILES[@]}; do
  FILENAME=$(echo $SPACING | cut -d "." -f 1)
  FILENAME=$(echo $FILENAME"_created.yaml")
  sed -i '/^$/d' $FILENAME # Remove all blank lines
  sed -i $'s/^[a-zA-Z]/\\\n&/g' $FILENAME # Add a blank line before each ITEM section
  sed -i '1{/^$/d}' $FILENAME # Remove the first blank line
  cat $FILENAME > $SPACING # Save file back to originsl
  rm -rf "$FILENAME" # Remove temp file
done
rm -rf "`pwd`/rebuild_temp.txt"
echo "Rebuild complete, entity_ids save to `pwd`/entity_id.txt"