#!/usr/bin/env bash

# This file contains functions to be used by bash programs in the containing repository.

# Allow aliases in this script.
shopt -s expand_aliases 2>/dev/null
# Use extended glob in this script.
shopt -s extglob


function print_time {

  # Print a formatted time stamp followed by any additional parameters passed.

  # Example:
  # print_time "Hello."

  # Output:
  # #(CST) 2020/02/06 17:53:42.833900 - Hello.

  echo "$(date +'#(%Z) %Y/%m/%d %H:%M:%S.%06N - ')${@}"

}


function print_error {

  # Print a formatted error message, which includes the caller's parameters, to stderr.

  # Example:
  # print_error "Invalid parameter."

  # Output:
  # #(CST) 2020/02/07 14:15:16.108436 - **ERROR** Invalid parameter.

  print_time "**ERROR**" "${@}" >&2

}


function print_issuing {
  local cmd_buf="${1:-${cmd_buf}}" ; shift
  local test_mode="${1:-0}" ; shift

  # Print a formatted line showing the command that is about to be issued.

  # Example:
  # cmd_buf=hostname
  # print_issuing

  # Output:
  # #(CST) 2020/02/06 17:57:46.096128 - Issuing: hostname

  # Example:
  # cmd_buf=hostname
  # print_issuing "${cmd_buf}" 1

  # Output:
  # #(CST) 2020/02/06 17:57:46.096128 - Issuing (test_mode): hostname

  # Description of argument(s):
  # cmd_buf    The command string to be printed in the "issuing" output.
  # test_mode  Print the test mode version of the message (see example above)..

  if (( test_mode )) ; then
    print_time "Issuing (test_mode): ${cmd_buf}"
  else
    print_time "Issuing: ${cmd_buf}"
  fi

}


function print_var {
  local var_name="${1}" ; shift
  local indent="${1:-0}" ; shift
  local col1_width="${1:-36}" ; shift

  # Print the variable name and its value in a formatted manner.

  # Example:
  # var1=5
  # print_var var1

  # Output:
  # var1:                                             5

  # Description of argument(s):
  # var_name    The name of the variable to print.
  # indent      The number of spaces to indent the output.
  # col1_width  The total width of the first column (minus the indent value).

  (( col1_width-=indent ))

  local cmd_buf
  cmd_buf="printf \"%-${indent}s%-${col1_width}s%s\n\" \"\" \"${var_name}:\" \"\${$var_name}\""
  eval ${cmd_buf}

}


function print_vars {

  # Call print var for each variable name passed.

  local var_name
  for var_name in "${@}" ; do
    print_var ${var_name}
  done

}


function normalize_path {
  local path="${1}" ; shift

  # Print the normalized path to stdout.

  # Description of argument(s):
  # path  The path to be printed.

  python -c "import os, sys; print(os.path.abspath(sys.argv[1]))" "${path}"

}


function search_list {
  local element="${1}" ; shift
  local list="${1}" ; shift
  local delim="${1:- }" ; shift

  # Return 0 if the element is an entry in the list.  Otherwise, return 1.

  # A list a simply a string with the elements separated by ${delim}.

  # Description of argument(s):
  # element  The list element to search for.
  # list     The delimited list to be search.
  # delim    The delimiter used to separate items in the list.

  [[ "${list}" =~ (^|${delim})${element}(${delim}|$) ]]

}


function add_list_element {
  local element="${1}" ; shift
  local list_name="${1}" ; shift
  local pos="${1:-back}" ; shift
  local delim="${1:- }" ; shift

  # Add an element to the list named in list_name.

  # Description of argument(s):
  # element                         The value to be added to the list.
  # list_name                       The name of the list.
  # pos                             The position to add to (front/back).
  # delim                           The delimiter which separates list elements.

  local cmd_buf
  local debug=0

  [ -z "${!list_name}" ] && delim=''
  if [ "${pos}" == "front" ] ; then
    cmd_buf="${list_name}=\"\${element}\${delim}\${!list_name}\""
    dprint_issuing
    eval "${cmd_buf}"
  else
    cmd_buf="${list_name}=\"\${!list_name}\${delim}\${element}\""
    dprint_issuing
    eval "${cmd_buf}"
  fi

}


function retrieve_list_element {
  local element_name="${1}" ; shift
  local list_name="${1}" ; shift
  local pos="${1:-back}" ; shift
  local delim="${1:- }" ; shift
  local remove="${1:-0}" ; shift
  local fail_on_empty="${1:-0}" ; shift

  # Retrieve an element from the list named in list_name and return it in the variable named in element_name.

  # Description of argument(s):
  # element_name                    The name of the variable that is to receive the result.
  # list_name                       The name of the list.
  # pos                             The position from which to remove (front/back).
  # delim                           The delimiter which separates list elements.
  # remove                          Remove the retrieved element from the list.
  # fail_on_empty                   Fail if the list is empty.  Otherwise, simply return a blank element.

  local cmd_buf
  local debug=0

  if (( fail_on_empty )) && [ -z "${!list_name}" ] ; then
    print_error "\"${list_name}\" is empty and therefore no entry may be retrieved from it."
    return 1
  fi

  if [ "${pos}" == "front" ] ; then
    cmd_buf="${element_name}=\${!list_name%%\${delim}*}"
    dprint_issuing
    eval "${cmd_buf}"
    if (( remove )) ; then
      cmd_buf="${list_name}=\${!list_name##\${${element_name}}?(\${delim})}"
      dprint_issuing
      eval "${cmd_buf}"
    fi
  else
    cmd_buf="${element_name}=\${!list_name##*\${delim}}"
    dprint_issuing
    eval "${cmd_buf}"
    if (( remove )) ; then
      cmd_buf="${list_name}=\${!list_name%%?(\${delim})\${${element_name}}}"
      dprint_issuing
      eval "${cmd_buf}"
    fi
  fi

}


function parse_name_value {
  local name_value="${1}" ; shift
  local name_var="${1}" ; shift
  local value_var="${1}" ; shift
  local default="${1}" ; shift
  local delim="${1:-=}" ; shift

  # Parse a name/value string and return the results in the named variables.

  # A name value string has the following format:
  # <var_name><delim><var_value>

  # Example:
  # string="adjective=blue"
  # parse_name_value "${string}" name value
  # print_vars name value

  # Output:
  # name:                               adjective
  # value:                              blue

  # Description of argument(s):
  # name_value  The name/value string.
  # name_var    The name of the variable that is to receive the name from the name_value string.
  # value_var   The name of the variable that is to receive the value from the name_value string.
  # default     The default value to be assigned if there is no delimiter in the name_value string.
  # delim       The delimiter which separates the name from the value in the name_value string.

  cmd "${name_var}=\${name_value%%${delim}*}"
  if [[ "${name_value}" == *${delim}* ]] ; then
    # The name_value string contains the delimiter.
    cmd "${value_var}=\"${name_value#*${delim}}\""
  else
    cmd "${value_var}='${default}'"
  fi

} > /dev/null


function cmd {
  local cmd_buf="${1:-${cmd_buf}}" ; shift
  local test_mode="${1:-0}" ; shift

  # Print an "Issuing:" statement and run the caller's command.

  # Example:
  # cmd hostname || return 1

  # Output:
  # #(CST) 2020/02/07 10:37:50.223731 - Issuing: hostname
  # gfwr802.rch.stglabs.ibm.com

  # Description of argument(s):
  # cmd_buf    The command string to be printed and run.
  # test_mode  Print the test mode version of the issuing message and then return 0.  I.e. don't actually run
  #            the command.

  local rc

  print_issuing "${cmd_buf}" ${test_mode}
  (( test_mode )) && return 0
  eval "${cmd_buf}"
  rc="${?}"
  if (( rc )) ; then
    print_error "The prior shell command failed."
    print_vars rc >&2
    return ${rc}
  fi

}


function t_cmd {

  # Call cmd and pass it the value of test_mode in the current scope.
  cmd "${@}" ${test_mode}

}


function get_pgm_name {

  # Populate the following global variables:
  # program_file_path  The full path of the program calling this function.
  # program_dir_path   The dir path of the program calling this function.
  # program_name       The unqualified name of the program calling this function.

  local source_file_path="${BASH_SOURCE[0]}"
  local ix
  # Get index of first BASH_SOURCE entry that is NOT for the current tools.bash file.
  for (( ix=1 ; ix < ${#BASH_SOURCE[@]} ; ix++ )) ; do
    [ "${BASH_SOURCE[${ix}]}" != "${source_file_path}" ] && break
  done

  local cmd="import os, sys; print(os.path.abspath(sys.argv[1]))"
  program_file_path=$(python -c "${cmd}" "${BASH_SOURCE[${ix}]}")
  program_dir_path="${program_file_path%/*}/"
  program_name=${program_file_path##*/}

}


function pos_parm_help {
  local parm_name="${1}" ; shift || :
  local parm_help_text="${1}" ; shift || :
  local print_default_text="${1:-1}" ; shift || :
  local column_width="${1:-${column_width:=45}}" ; shift || :

  # Print the supplied help text for the positional parameter named in parm_name.

  # Example:

  # pos_parm_help machine "The name of the simics machine that should be started (e.g. "denali", etc.)."

  # Output:

  # MACHINE                     The name of the simics machine that should be started (e.g. denali, etc.).
  # The default value is "denali".

  # This function will print the supplied help text for the parm named in parm_name.
  # parm_name           The name of the parameter.
  # parm_data_desc      The kind of data for the parameters argument.  Examples: "y/n", "hostname" or "1..100".
  # parm_help_text      The help text you wish to have printed.
  # print_default_text  A boolean (1/0) indicating whether you wish to have a line like this appended to your help text:
  #                       The default value is "x".
  # column_width        The width of the column containing parm_name=<$parm_data_desc>

  local default_text=""

  if (( print_default_text )) ; then
    default_text="  The default value is \"${!parm_name}\"."
  fi

  if type tr >/dev/null 2>&1 ; then
    parm_name=$(echo $parm_name | tr '[:lower:]' '[:upper:]')
  else
    change_case parm_name 1
  fi

  printf "%-${column_width}s%s\n" "  ${parm_name}" "${parm_help_text}${default_text}"

}

function parm_help {
  local parm_name="${1}" ; shift || :
  local parm_data_desc="${1}" ; shift || :
  local parm_help_text="${1}" ; shift || :
  local print_default_text="${1:-1}" ; shift || :
  local column_width="${1:-${column_width:=45}}" ; shift || :

  # Print the supplied help text for the parameter named in parm_name.

  # Example:
  # parm_help mw_toolkit "0/1" "This indicates whether mw_toolkit should be installed."

  # Output:
  #   --mw_toolkit=<0/1>          This indicates whether mw_toolkit should be installed.  The
  # default value is "1".

  # Description of argument(s):
  # parm_name           The name of the parameter.
  # parm_data_desc      The kind of data for the parameters argument, (e.g. "0/1", "hostname" or
  #                     "1..100").
  # parm_help_text      The help text to be printed.
  # print_default_text  A boolean (1/0) indicating whether you wish to have a line like this
  #                     appended to your
  #                     help text: The default value is "x".
  # column_width        The width of the column containing parm_name=<$parm_data_desc>

  local default_text
  local parm_data_desc_text

  (( print_default_text )) && default_text="  The default value is \"${!parm_name}\"."
  [ ! -z "${parm_data_desc}" ] && parm_data_desc_text="=<${parm_data_desc}>"

  printf "%-${column_width}s%s\n" "  --${parm_name}${parm_data_desc_text}" \
    "${parm_help_text}${default_text}"

}


function print_test_mode_help_text {

  # Print the stock help text for the test_mode parameter.

  parm_help_text="Go through all the motions but don't actually do anything substantial.  This is mainly to be used by the developer of ${program_name}."

  parm_help test_mode "0/1" "${parm_help_text}"

}


function print_quiet_help_text {

  # Print the stock help text for the quiet parameter.

  parm_help_text="Print only essential information, i.e. it do not echo parameters, echo commands, print the"
  parm_help_text="${parm_help_text} total run time, etc."

  parm_help quiet "0/1" "${parm_help_text}"

}


function print_debug_help_text {

  # Print the stock help text for the debug parameter.

  parm_help_text="Print additional debug information."

  parm_help debug "0/1" "${parm_help_text}"

}


function print_stock_help_text {

  # Print stock help text for any stock parameters that are defined in the global longoptions list.
  local stock_parms="test_mode quiet debug"

  for parm_name in ${stock_parms} ; do
    # Continue if parm_name is not in global longoptions.
    search_list "${parm_name}" "${longoptions}" || continue
    eval print_${parm_name}_help_text
  done

}


function longoptions {

  # Process each parameter passed as follows:

  # - Set the global value of the parameter variable (with the default if supplied).
  # - Add the parameter variable name to the global longoptions variable.

  # Example:

  # longoptions ebmc_pkg=1 mw_toolkit=1 debug=0
  # print_vars longoptions ${longoptions}

  # Output:

  # longoptions:                        ebmc_pkg mw_toolkit debug
  # ebmc_pkg:                           1
  # mw_toolkit:                         1
  # debug:                              0

  local parm
  local parm_name
  local parm_value

  for parm in "${@}" ; do
    parse_name_value "${parm}" parm_name parm_value
    # Set a global value for the parameter.
    cmd "${parm_name}=\"\${parm_value}\"" > /dev/null

    # Append parm_name to global longoptions.
    longoptions="${longoptions} ${parm_name}"
  done

  # Trim leading spaces.
  longoptions="${longoptions## }"

}


function pos_parms {

  # Process each parameter passed as follows:

  # - Set the global value of the parameter variable (with the default if supplied).
  # - Add the parameter variable name to the global pos_parms variable.

  # Example:

  # pos_parms machine=denali
  # print_vars pos_parms ${pos_parms}

  # Output:

  # pos_parms:                          machine
  # machine:                            denali

  local parm
  local parm_name
  local parm_value

  for parm in "${@}" ; do
    parse_name_value "${parm}" parm_name parm_value
    # Set a global value for the parameter.
    cmd "${parm_name}=\"\${parm_value}\"" > /dev/null

    # Append parm_name to global pos_parms.
    pos_parms="${pos_parms} ${parm_name}"
  done

  # Trim leading spaces.
  pos_parms="${pos_parms## }"

}


function process_help_parm {
  local help="${1:-0}"

  # Process the help parameter:

  # If help is not set, return.
  # If caller has no help function defined, print an error and exit 1.
  # Invoke the caller's help function and exit.

  (( ! help )) && return

  local type_name=$(type -t help)
  if [ "${type_name}" == "function" ] ; then
    help
    exit
  else
    print_error "No help text is defined for this program."
    exit 1
  fi

}


function process_pgm_parms {

  # Process program parameters.

  # Note that the caller must include all legitimate parameters in a space-delimited list in global
  # variable longoptions.

  # Processing includes the following:

  # - For each valid parameter, create a global variable whose name equals the parameter name and
  #   set its value to the parameter value.
  # - Add each parameter variable name to the global parm_list.
  # - Create global command_line variable.

  # All parameters must be specified in the following format:
  # <one or more dashes><parameter name>=[<parameter value>]

  # If no parameter value is specified on the command line, the value is presumed to be 1.

  # A parameter of "-h" is automatically converted to "--help".

  # If -h or --help is specified, this function will call the programmer's help function and exit.

  local cmd_buf
  local parm
  local parm_name
  local parm_value
  local debug=0

  get_pgm_name || return 1

  local local_pos_parms=${pos_parms}
  local current_pos_parm
  local pos_parm
  local remove=1
  local fail_on_empty=0

  command_line="${program_file_path} ${@}"
  local last_pos_parm
  for parm in "${@}" ; do
    [ "${parm}" == "-h" ] && parm="--help"
    # Strip one or more leading dashes.
    parm="${parm##+(-)}"
    parse_name_value "${parm}" parm_name parm_value 1
    if ! search_list "${parm_name}" "${longoptions} help" ; then
      # See if the programmer has specified pos parms.
      retrieve_list_element pos_parm local_pos_parms front " " ${remove} ${fail_on_empty}
      # If the local_pos_parms was empty, see if we have a pos_parm from the prior loop iteration.
      [ -z "${pos_parm}" ] && pos_parm="${last_pos_parm}"
      if [ -z "${pos_parm} -a -z ${last_pos_parm}" ] ; then
        print_error "${parm_name} is an unrecognized parameter."
        process_help_parm 1
        exit 1
      fi
      parm_value="${parm_name}"
      parm_name=${pos_parm}
      if [ "${pos_parm}" == "${last_pos_parm}" ] ; then
        add_list_element "${parm_value}" "${parm_name}" back " " || exit 1
      else
        # Set a global value for the parameter.
        cmd_buf="${parm_name}=\"\${parm_value}\""
        dprint_issuing
        eval "${cmd_buf}"
      fi
      last_pos_parm="${pos_parm:-${last_pos_parm}}"
      [ ! -z "${pos_parm}" ] && last_pos_parm="${pos_parm}"
    else
      # Set a global value for the parameter.
      cmd_buf="${parm_name}=\"\${parm_value}\""
      dprint_issuing
      eval "${cmd_buf}"
    fi

    # Append parm_name to parm_list.
    parm_list="${parm_list} ${parm_name}"
    process_help_parm ${help}

  done

  # Trim leading spaces.
  parm_list="${parm_list## }"

}


function print_pgm_header {

  # Print a program header.

  echo
  print_time Running "${program_name}."
  print_time "Program parameter values, etc.:"
  echo
  pid="${$}"
  gpid="$(echo $(ps -opgid --no-headers ${pid}))"
  uid="${UID} (${USER})"
  gid="${GROUPS} (${USER})"
  host_name=${HOSTNAME}
  print_vars command_line pid gpid uid gid host_name DISPLAY PWD ${longoptions} ${pos_parms}
  echo

}


function print_pgm_footer {

  # Print a program footer.

  echo
  print_time Finished running "${program_name}."
  echo

}


function add_trailing_char {
  local var_name="${1}" ; shift
  local char="${1:-/}" ; shift

  # Make sure that var_name has one and only one char character at the end.

  # Description of argument(s):
  # var_name  The name of the variable to be manipulated.
  # char      The char to be added to the end of the variable.

  local cmd_buf
  cmd_buf="${var_name}=\"\${${var_name}%%+(\${char})}\${char}\""
  eval "${cmd_buf}"

}


# Validation functions.
function valid_dir_path {
  local dir_path_var="${1}" ; shift || :
  local normalize_path="${1:-1}" ; shift || :

  # Fail if the directory indicated by the variable named in dir_path_var does not exist.

  # Description of argument(s):
  # dir_path_var        The name of the variable that contains a directory path.
  # normalize_path      Normalize the path and make sure it ends in a slash.

  if (( normalize_path )) ; then
    local cmd_buf
    cmd_buf="${dir_path_var}=$(normalize_path ${!dir_path_var})/"
    eval "${cmd_buf}"
  fi

  [ -d "${!dir_path_var}" ] && return 0

  print_error "Directory does not exist."
  print_vars ${dir_path_var} >&2
  return 1

}


# Get list of all print functions in this file.
print_funcs=$(egrep '^function print_' ${BASH_SOURCE} | cut -f 2 -d ' ' ; echo echo)

# Make "d" and "q" versions of all print_funcs in this file:
# e.g. qprint_var calls print_var provided that quiet is 0.
# e.g. dprint_var calls print var only if debug is 1.
# DEBUG is set.
for func_name in ${print_funcs} ; do
  cmd_buf="function d${func_name} { (( \${DEBUG:-\${debug:-0}} )) && ${func_name} \"\${@}\" ; }"
  eval "${cmd_buf}"

  cmd_buf="function q${func_name} { (( \${quiet:-0} )) || ${func_name} \"\${@}\" ; }"
  eval "${cmd_buf}"

done
