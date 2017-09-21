#!/bin/bash

#
# Helper functions
#

neural_style(){
    content=$1
    style=$2
    savefolder=$3
    otherparams=$4
    th /style-swap/style-swap.lua \
        --save ${savefolder} \
        --decoder /style-swap/models/dec-tconv-sigmoid.t7 \
        --content ${content} \
        --style ${style} \
        ${otherparams}
}

neural_tile(){
    MAXTILESIZE=350
    OVERLAP=50

    # Check for output directory, and create it if missing
    if [ ! -d "$output" ]; then
      mkdir output
    fi

	# 1. Defines the content image as a variable
	input=$1
	input_file=`basename $input`
	clean_name="${input_file%.*}"

	# Gather size info from original image
	original_w=`convert ${input} -format "%w" info:`
	original_h=`convert ${input} -format "%h" info:`

	# Compute number of tiles required to map all the image
	XTILES=$(python -c "from math import ceil; print(ceil(float(${original_w}-$MAXTILESIZE) / float($MAXTILESIZE-$OVERLAP) + 1))")
	YTILES=$(python -c "from math import ceil; print(ceil(float(${original_h}-$MAXTILESIZE) / float($MAXTILESIZE-$OVERLAP) + 1))")
	TILES=$(python -c "print(int($XTILES * $YTILES))")

	#Defines the style image as a variable
	style=$2
	style_dir=`dirname $style`
	style_file=`basename $style`
	style_name="${style_file%.*}"

	#Defines the output directory
	output="./output"
	out_file=$output/$input_file

	# 2. Creates your original styled output. This step will be skipped if you place a previously styled image with the same name
	# as your specified "content image", located in your Neural-Style/output/<Styled_Image> directory.
	if [ ! -s $out_file ] ; then
		neural_style_overall ${input} ${style} ${out_file}
        upscaled=$(mktemp XXXXXXXXXX)
        convert ${out_file} -resize ${original_w} ${upscaled}
		blend ${upscaled} ${input} ${out_file} 50  # TODO: this helps a bit, but does not solve the problem
		rm -f ${upscaled}
	fi

	# 3. Chop the styled image into tiles with the specified overlap value.
	out_dir=$output/$clean_name
	mkdir -p $out_dir
	convert ${out_file} -crop "$XTILES"x"$YTILES"+"$OVERLAP"+"$OVERLAP"@ +repage +adjoin ${out_dir}/${clean_name}"_%d.png"

	#Finds out the length and width of the first tile as a reference point for resizing the other tiles.
	original_tile_w=`convert $out_dir/$clean_name'_0.png' -format "%w" info:`
	original_tile_h=`convert $out_dir/$clean_name'_0.png' -format "%h" info:`

	# 4. neural-style each tile
	tiles_dir="$out_dir/tiles"
	mkdir -p $tiles_dir
	neural_style_tiled ${out_dir} ${style} ${tiles_dir}

	#Perform the required mathematical operations:

	upres_tile_w=`convert ${tiles_dir}/$clean_name'_0.png' -format "%w" info:`
	echo "upres_tile_w=${upres_tile_w}"
	upres_tile_h=`convert ${tiles_dir}/$clean_name'_0.png' -format "%h" info:`
	echo "upres_tile_h=${upres_tile_h}"

	tile_diff_w=`echo $upres_tile_w $original_tile_w | awk '{print $1/$2}'`
	echo "tile_diff_w=${tile_diff_w}"
	tile_diff_h=`echo $upres_tile_h $original_tile_h | awk '{print $1/$2}'`
	echo "tile_diff_h=${tile_diff_h}"

	smush_value_w=`echo $OVERLAP $tile_diff_w | awk '{print $1*$2}'`
	echo "smush_value_w=${smush_value_w}"
	smush_value_h=`echo $OVERLAP $tile_diff_h | awk '{print $1*$2}'`
	echo "smush_value_h=${smush_value_h}"

	# 5. feather tiles
	feathered_dir=$out_dir/feathered
	mkdir -p $feathered_dir
	for tile in `ls $tiles_dir | grep "${clean_name}_[0-9]*.png"`
	do
		tile_name="${tile%.*}"
		convert $tiles_dir/$tile -alpha set -virtual-pixel transparent -channel A -morphology Distance Euclidean:1,50\! +channel "$feathered_dir/$tile_name.png"
	done

	# 6. Smush the feathered tiles together
	i=0
	command="-background transparent "
	for row in $(seq ${YTILES})
	do
	    rowcmd=""
	    for col in $(seq ${XTILES})
	    do
	        rowcmd="$rowcmd $feathered_dir/${clean_name}_${i}.png"
	        let i++
	    done
	    rowcmd="$rowcmd +smush -$smush_value_w -background transparent"
	    command="$command ( $rowcmd )"
	done
	command="$command -background none  -background transparent -smush -$smush_value_h  $output/$clean_name.large_feathered.png"
	convert ${command}

	# 7. Smush the non-feathered tiles together
	i=0
	command=""
	for row in $(seq ${YTILES})
	do
	    rowcmd=""
	    for col in $(seq ${XTILES})
	    do
	        rowcmd="$rowcmd ${tiles_dir}/${clean_name}_${i}.png"
	        let i++
	    done
	    rowcmd="$rowcmd  +smush -$smush_value_w"
	    command="$command ( $rowcmd )"
	done
	command="$command -background none -smush -$smush_value_h  $output/$clean_name.large.png"
	convert ${command}

	# 8. Combine feathered and un-feathered output images to disguise feathering.
	composite $output/$clean_name.large_feathered.png $output/$clean_name.large.png $output/$clean_name.large_final.png

	# Adjust back to desired size
	convert $output/$clean_name.large_final.png -resize "$original_w"x"$original_h"\! ${output}/${clean_name}.result.png

    # 9. Save final image
    mv ${output}/${clean_name}.result.png $3
}

neural_style_overall(){
    # Overall neural style pass for the tiling algorithm
	echo "Neural Style Transfering "$1

    indir=$(mktemp -d)
    outdir=${indir}/out
    mkdir ${outdir}

    convert $1 -resize $MAXTILESIZE $indir/$(basename $1)
    convert $2 -resize $MAXTILESIZE $indir/$(basename $2)

    (neural_style $indir/$(basename $1) $indir/$(basename $2) ${outdir} "--maxContentSize $MAXTILESIZE --maxStyleSize $MAXTILESIZE")

    cp ${outdir}/*_stylized.* $3
    rm -rf $indir
}

neural_style_tiled(){
    # Neural Style tiles pass for the tiling algorithm
	echo "Neural Style Transfering tiles from directory "$1
    indir=$(mktemp -d)
    styledir=${indir}/style
    mkdir ${styledir}
    outdir=${indir}/out
    mkdir ${outdir}

    for tile in $(ls $1/*.png)
    do
        cp ${tile} ${indir}/$(basename ${tile})
    done
    stylesize=$MAXTILESIZE
    convert $2 -resize $stylesize $styledir/$(basename $2)

    th /style-swap/style-swap.lua \
      --decoder /style-swap/models/dec-tconv-sigmoid.t7 \
      --contentBatch ${indir} \
      --style ${styledir}/$(basename $2) \
      --save ${outdir}  \
      --maxContentSize $stylesize \
      --maxStyleSize $stylesize \
      --optimIter 20 \
      --tv 1e-6
    mv ${outdir}/*_stylized.* $3
    # Rename images to remove the "_stylized" suffix the transfer algorithm adds
    rename 's/_stylized//' $(ls $3/*.png)
    rm -rf $indir
}

blend(){
    # Blends two images into one, with equal transparency
    in1=$1
    in2=$2
    out=$3
    weight=$4
    convert -background transparent ${in1} ${in2} -compose blend -define compose:args=${weight} -composite ${out}
}



#
# Entrypoint script to style algorithm
#

# Process params so that references to inputs are located in the mounted /images directory
otherparams=""
tiling=0
savefolder="/images"
outfile="output.png"
while [ "$1" != "" ]; do
    option="$1"
    case ${option} in
       "--content")
        shift
        content="/images/${1}"
        ;;
       "--style")
        shift
        style="/images/${1}"
        ;;
       "--save")
        shift
        savefolder="/images/${1}"
        ;;
       "--tiling")
        tiling=1
        ;;
       "--outfile")
        shift
        outfile=${1}
        ;;
       *)
        otherparams="${otherparams} ${option}"
        ;;
    esac
    shift
done

# Call main application with processed parameters
if [[ ${tiling} == 1 ]]
then
    neural_tile ${content} ${style} ${savefolder}/${outfile}
else
    neural_style ${content} ${style} ${savefolder} "${otherparams}" # TODO: make use of ${outfile}
fi
