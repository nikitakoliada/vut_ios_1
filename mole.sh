#!/bin/bash

export POSIXLY_CORRECT=yes
export LC_ALL=C


# Constants
MOLE_RC="$HOME/MOLE_RC"
LOG_DIR="$HOME/.mole"
EDITOR="${EDITOR:-${VISUAL:-vi}}"

# Function to print help TODO
help() {
  echo "Usage: mole [OPTIONS] [DIRECTORY]"
      echo "Options:"
      echo "  -h                             Display help message."
      echo "  [-g GROUP] FILE                Open file and assign(optional) the opened file to the specified group."
      echo "  [FILTERS] [DIRECTORY]          Select the file that has been opened the last."
      echo "  [-m] [FILTERS] [DIRECTORY]     Select the file in the directory that has been opened the most."
      echo "  list [FILTERS] [DIRECTORY]     Display a list in the directory of files opened using filters."
      echo " Filters(optional):"
      echo "  [-g GROUP1[,GROUP2[,...]]]     Groups specification, the file(s) must be at least in one of the specified groups"
      echo "  [-a DATE][-b DATE]             Specification of date -b before and -a after specific date."
      echo " "
      echo "  *[DIRECTORY] is by default current directory.*"
}

# Function to open a file
open_file() {

  if [ -f $1 ]; then
      file=$(realpath "$1")
      group=$2
      current_date=$(date +"%Y-%m-%d_%H-%M-%S")
      if [ ! -f $MOLE_RC ]; then
        touch $MOLE_RC
      fi
      echo "$file $current_date $group" >> $MOLE_RC
      $EDITOR $file
    else
      echo "The file does not exist or is not a regular file."
      exit 1
    fi


}
#TODO refactorize
find_last_file_by_date() {
if [ "$1" == "." ]; then
      directory=$(realpath .)
    else
      directory=$(realpath "$1")
    fi
    groups=$2
    after_date=$3
    before_date=$4
    current_date=$(date +"%Y-%m-%d_%H-%M-%S")
    file=$(tac "$MOLE_RC" | awk -v group="$groups" -v dir="$directory" -v before="$before_date" -v after="$after_date" '{
    if (group != "") {
    split(group, arr, ",")
    for (i in arr) {
            if ($3 == arr[i]  &&  $1 ~ "^" dir && after < $2 && $2 < before && system("[ -e "$1" ]") == 0) {
              cmd = "realpath --relative-to=\"" dir "\" \"" $1 "\""
              cmd | getline relative_path
              close(cmd)
              if (index(relative_path, "/") == 0) {
                  print $1
                  exit
              }
            }
        }
    }else{
        if ($1 ~ "^" dir && after < $2 && $2 < before && system("[ -e "$1" ]") == 0) {
            cmd = "realpath --relative-to=\"" dir "\" \"" $1 "\""
            cmd | getline relative_path
            close(cmd)
            if (index(relative_path, "/") == 0) {
                print $1
                exit
            }
        }
    }
    }' | tac )
    if [[ -n $file ]]; then
      echo "$file $current_date" >> $MOLE_RC
      echo "$file"
    else
      echo "Error: no file found"
      exit 1
    fi
  }

find_mfrequent_file_by_date() {
    if [ "$1" == "." ]; then
      directory=$(realpath .)
    else
      directory=$(realpath "$1")
    fi
    groups=$2
    after_date=$3
    before_date=$4
    current_date=$(date +"%Y-%m-%d_%H-%M-%S")
    file=$(awk -v group="$groups" -v dir="$directory" -v before="$before_date" -v after="$after_date" '{
    if (group != "") {
    split(group, arr, ",")
    for (i in arr) {
            if ( $3 == arr[i] &&  $1 ~ "^" dir && after < $2 && $2 < before && system("[ -e "$1" ]") == 0) {
                cmd = "realpath --relative-to=\"" dir "\" \"" $1 "\""
                cmd | getline relative_path
                close(cmd)
                if (index(relative_path, "/") == 0) {
                    print $1
                }
            }
        }
    }else{
        if ($1 ~ "^" dir && after < $2 && $2 < before && system("[ -e "$1" ]") == 0) {
            cmd = "realpath --relative-to=\"" dir "\" \"" $1 "\""
            cmd | getline relative_path
            close(cmd)
            if (index(relative_path, "/") == 0) {
                print $1
            }
        }
    }
    }' "$MOLE_RC" | awk '{ count[$1]++ } END { max = 0; for (val in count) if (count[val] > max) { max = count[val]; maxval = val } print maxval }')
    if [[ -n $file ]]; then
      echo "$file"
      echo "$file $current_date" >> $MOLE_RC
    else
      echo "Error: no file found"
      exit 1
    fi
  }

show_list(){
  if [ "$1" == "." ]; then
    directory=$(realpath .)
  else
    directory=$(realpath "$1")
  fi
  groups=$2
  after_date=$3
  before_date=$4
  selected_files=$(awk -v group="$groups" -v dir="$directory" -v before="$before_date" -v after="$after_date" '{
    if (group != "") {
    split(group, arr, ",")
    for (i in arr) {
            if ($3 == arr[i] && $1 ~ "^" dir && after < $2 && $2 < before && system("[ -e "$1" ]") == 0) {
                cmd = "realpath --relative-to=\"" dir "\" \"" $1 "\""
                cmd | getline relative_path
                close(cmd)
                if (index(relative_path, "/") == 0 && !printed_files[relative_path]) {
                    printf "%s ", $1
                    printed_files[relative_path] = 1
                }
                }
        }
    }else{
        if ($1 ~ "^" dir && after < $2 && $2 < before && system("[ -e "$1" ]") == 0) {
            cmd = "realpath --relative-to=\"" dir "\" \"" $1 "\""
                        cmd | getline relative_path
                        close(cmd)
                        if (index(relative_path, "/") == 0 && !printed_files[relative_path]) {
                            printf "%s ", $1
                            printed_files[relative_path] = 1
                        }
        }
    }
    }' "$MOLE_RC" )

    list=$(awk -v groups=$groups -v dir=$directory -v file_mole=$MOLE_RC -v select_files="$selected_files" '{
        split(select_files, sel_files, " ")
        for (file in sel_files) {
            sel_groups = ""
            if (groups != "") {
                split(groups, arr, ",")
                for (group in arr) {
                  delete added_groups
                  while ((getline line < file_mole) > 0){
                    split(line, fields, " ")
                    if (fields[1] == sel_files[file] && fields[3] == arr[group] && !added_groups[fields[3]]) {
                        sel_groups = sel_groups ", " fields[3]
                        added_groups[fields[3]] = 1
                    }
                  }
                  close(file_mole)
                }
              cmd = "basename " sel_files[file]
              cmd | getline basename
              close(cmd)
              print basename ":" substr(sel_groups, 2)
            }
            else{
              delete added_groups
              while ((getline line < file_mole) > 0){
                split(line, fields, " ")
                if (fields[1] == sel_files[file] && fields[3] != "" && !added_groups[fields[3]]) {
                    sel_groups = sel_groups ", " fields[3]
                    added_groups[fields[3]] = 1
                }
              }
              close(file_mole)
              cmd = "basename " sel_files[file]
              cmd | getline basename
              close(cmd)
              if(sel_groups != ""){
                  print basename ":" substr(sel_groups, 2)
              }else{
                  print basename ": " "-"
               }
            }
        }
    }' $MOLE_RC | sort -u)

    if [[ -n $list ]]; then
          echo "$list"
        else
          echo "Error: no files found"
          exit 1
        fi
}

create_secret_log(){
  if [ "$1" == "." ]; then
    directories=""
  else
    directories=$1
  fi
  after_date=$2
  before_date=$3
  selected_files=$(awk -v dirs="$directories" '{
    if(dirs!=""){
    split(dirs, dir, " ")
      for (i in dir) {
        cmd = "realpath " dir[i]
        cmd | getline realpath
        close(cmd)
        if ($1 ~ "^" realpath && system("[ -e "$1" ]") == 0) {
           printf "%s ", $1
        }
      }
    }else{
      if (system("[ -e "$1" ]") == 0){
           printf "%s ", $1
      }
    }
    }' "$MOLE_RC" | sort -k1)

    list=$(awk -v before="$before_date" -v after="$after_date" -v file_mole="$MOLE_RC" -v selected_files="$selected_files" '{
        split(selected_files, sel_files, " ")
        for (file in sel_files) {
          selected=""
                  delete added_dates
                  while ((getline line < file_mole) > 0){
                    split(line, fields, " ")
                    if (fields[1] == sel_files[file] && fields[2] < before && after < fields[2] && !added_dates[fields[2]]) {
                        selected = selected ";" fields[2]
                        added_dates[fields[2]] = 1
                    }
                  }
                  close(file_mole)
                
                print sel_files[file] ";" substr(selected, 2)

        }
    }' "$MOLE_RC" | sort -u)

    if [ ! -d $LOG_DIR ]; then
       mkdir -p $LOG_DIR
    fi
    # Set the log file name using the current user name and date/time
    LOG_FILE="$LOG_DIR/log_$(whoami)_$(date '+%Y-%m-%d_%H-%M-%S')"
    touch $LOG_FILE
    if [[ -n $list ]]; then
      echo "$list" >> "$LOG_FILE"
      bzip2 "$LOG_FILE"
    else
      echo "Error: no files found"
      exit 1
    fi
}



  if [[ "$1" = "-h" ]]; then
    help
    exit 1
  fi

  directory="."
  mode="last"
  groups=""
  after_date="0001-01-01"
  before_date="3000-12-12"

  if [[ "$1" == "list" ]]; then
    shift
    while getopts ":g:a:b:" opt; do
        case $opt in

          g)
            groups=$OPTARG
             ;;
          a)
            after_date=$OPTARG
            ;;
           b)
             before_date=$OPTARG
            ;;
          \?)
            echo "Invalid option: -$OPTARG" >&2
             exit 1
             ;;
           :)
             echo "Option -$OPTARG requires an argument." >&2
            exit 1
             ;;
         esac
      done
    shift $((OPTIND-1))
    if [ $# -eq 1 ]; then
      if [ -d $1 ]; then
        directory=$1
      else
         echo "Not a directory" >&2
         exit 1
      fi
    elif [ $# -gt 1 ]; then
      echo "Too many arguments." >&2
      exit 1
    fi
    show_list "$directory" "$groups" "$after_date" "$before_date"
    exit 1
  elif [[ "$1" == "secret-log" ]]; then
      shift
      # parse command-line arguments
      while [[ $# -gt 0 ]]; do
          case "$1" in
              -b)
                  end_date="$2"
                  shift 2
                  ;;
              -a)
                  start_date="$2"
                  shift 2
                  ;;
              *)
                  directories+=("$1")
                  shift
                  ;;
          esac
      done
      create_secret_log "$directories" "$after_date" "$before_date"
      exit 1
  else

    while getopts ":mg:a:b:" opt; do
        case $opt in
          m)
            mode="most"
            ;;
          g)
            groups=$OPTARG
             ;;
          a)
            after_date=$OPTARG
            ;;
           b)
             before_date=$OPTARG
            ;;
          \?)
            echo "Invalid option: -$OPTARG" >&2
             exit 1
             ;;
           :)
             echo "Option -$OPTARG requires an argument." >&2
            exit 1
             ;;
         esac
      done
    # Remove parsed options from arguments
    shift $((OPTIND-1))
    if [ $# -eq 1 ]; then
      if [ -f $1 ]; then
        open_file $1 $groups
        exit 1
      elif [ -d $1 ]; then
        directory=$1
      else
        echo "No file or directory was found" >&2
        exit 1
      fi
    elif [ $# -gt 1 ]; then
      echo "Too many arguments." >&2
      exit 1
    fi

    #TODO REFACTORIZE
    # find the last or most frequently edited file in the directory
    if [[ $mode == "last" ]]; then
      #last modified
      file=$(find_last_file_by_date "$directory" "$groups" "$after_date" "$before_date")
    elif [[ $mode == "most" ]]; then
      #most frequently modified
      file=$(find_mfrequent_file_by_date "$directory" "$groups" "$after_date" "$before_date")
    fi

    # open the selected file
    if [[ -z $file ]]; then
      echo "No matching file found in directory $directory" >&2
      exit 1
    else
      echo "Opening file: $file"
      "$EDITOR" "$file"
    fi
fi

