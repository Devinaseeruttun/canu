#!/bin/bash

###############################################################################
 #
 #  This file is part of canu, a software program that assembles whole-genome
 #  sequencing reads into contigs.
 #
 #  This software is based on:
 #    'Celera Assembler' (http://wgs-assembler.sourceforge.net)
 #    the 'kmer package' (http://kmer.sourceforge.net)
 #  both originally distributed by Applera Corporation under the GNU General
 #  Public License, version 2.
 #
 #  Canu branched from Celera Assembler at its revision 4587.
 #  Canu branched from the kmer project at its revision 1994.
 #
 #  Modifications by:
 #
 #    Sergey Koren beginning on 2018-MAY-1
 #      are a 'United States Government Work', and
 #      are released in the public domain
 #
 #  File 'README.licenses' in the root directory of this distribution contains
 #  full conditions and disclaimers for each license.
 ##

fetch_and_run() {
   env

   echo "Value of executable $script_name"
   echo "Value of path $canu_path"
   echo "Value of array ID $DX_ARRAY_ID"
   echo "Value of iter is $canu_iteration"
   echo "Value of max is $canu_iteration_max"
   output_path=`cat dnanexus-job.json |tr ',' '\n'|grep folder |awk -F ": " '{print $NF}' |sed s/,//g |sed s/\"//g`
   echo "Value of output path is $output_path"

   if [ "x"$canu_iteration != "x" ] && [ $canu_iteration -gt $canu_iteration_max ]; then
      echo "Error: tried $canu_iteration times, giving up."
      exit 1
   fi

   # if we have a location, change there and download/run the script
   if [ x"$canu_path" != "x" ]; then
      mkdir -p $canu_path
      cd $canu_path
   else
      # here we know we're the canu executable so pass through the iteration counts so they can be updated for canu
      canuPath=`which canu`
      canuPath=`dirname $canuPath`
      echo "canuIteration=$canu_iteration"        >  $canuPath/canu.defaults
      echo "canuIterationMax=$canu_iteration_max" >> $canuPath/canu.defaults
cat $canuPath/canu.defaults
   fi
   dx download $DX_PROJECT_CONTEXT_ID:$output_path/$canu_path/$script_name
   export DX_ARRAY_ID=$DX_ARRAY_ID

   bash $script_name
}

main() {
    env

    echo "Value of input_files_names '${input_files_name[@]}'"
    echo "Value of input_file_types: '${input_type}'"
    echo "Value of output_prefix '${output_prefix}'"
    echo "Value of genome size '${genome_size}'"
    echo "Value of parameters '${parameters}'"

    output_path=`cat dnanexus-job.json |tr ',' '\n'|grep folder |awk -F ": " '{print $NF}' |sed s/,//g |sed s/\"//g`
    echo "Value of output path is $output_path"

    for i in ${!input_files[@]}
    do
        dx download "${input_files[$i]}"
    done

    if [ ! -s ${output_prefix}.contigs.fasta ]; then
       # save the command without the inputs
       echo "canu objectStore=DNANEXUS objectStoreClient=dx objectStoreNameSpace=$output_path objectStoreProject=$DX_PROJECT_CONTEXT_ID -d . -p ${output_prefix} genomeSize=${genome_size} $parameters" > canu.sh
       exists=`dx describe --name $DX_PROJECT_CONTEXT_ID:$output_path/canu.sh`
       if [ -e canu.sh -o x$exists != x ] ; then
           dx rm --recursive $DX_PROJECT_CONTEXT_ID:$output_path/canu.sh
       fi
       dx upload --wait --parents --path $DX_PROJECT_CONTEXT_ID:$output_path/canu.sh canu.sh

       # run the canu command
       canu objectStore=DNANEXUS objectStoreClient=dx objectStoreNameSpace=$output_path objectStoreProject=$DX_PROJECT_CONTEXT_ID -d . -p ${output_prefix} genomeSize=${genome_size} $parameters ${input_type} ${input_files_name[@]}
    fi
}