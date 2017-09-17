#!/usr/bin/env bash

# Generates an image incrementally, so as to produce multiscale resolution effects

content=$1
style=$2
output=$3

neural_style(){
	echo "Neural Style Transfering "$1
    if groups $USER | grep &>/dev/null '\bdocker\b'; then SU=""
    else SU="sudo"; fi

    indir=$(mktemp -d)
    outdir=${indir}/out
    mkdir ${outdir}

    convert $1 -resize $4 $indir/$(basename $1)
    convert $2 -resize $4 $indir/$(basename $2)

    $SU nvidia-docker run --rm \
      -v $indir:/images albarji/style-swap \
      --content $(basename $1) \
      --style $(basename $2) \
      --save /out  \
      --maxContentSize $4 \
      --maxStyleSize $4
    cp $outdir/*_stylized.* $3
    rm -rf $indir
}

blend(){
    # Blends two images into one, with equal transparency
    in1=$1
    in2=$2
    out=$3
    convert -background transparent ${in1} ${in2} -compose blend -define compose:args=50 -composite ${out}
}

multiresolution_step(){
    # Performs a step in the multiresolution algorithm
    content=$1      # Original content image
    style=$2        # Style to apply
    resolution=$3   # Desired output resolution after this step
    previous=$4     # Result image of previous step
    out=$5          # File in which to save result of this step

    set -x  # FIXME
    trap read debug  # FIXME

    # Upscale result of previous step to current resolution
    upscaled=$(mktemp XXXXXXXXXX)
    convert ${previous} -resize ${resolution} ${upscaled}
    # Downscale content image to current resolution
    downscaled=$(mktemp XXXXXXXXXX)
    convert ${content} -resize ${resolution} ${downscaled}
    # Blend both images, to create a base for this step
    blended=$(mktemp XXXXXXXXXX)
    blend ${upscaled} ${downscaled} ${blended}
    # Run neural style
    neural_style ${blended} ${style} ${out} ${resolution}

    # Delete temporaries
    rm -f ${upscaled} ${downscaled} ${blended}
}

infile=$(mktemp XXXXXXXXXX)
outfile=$(mktemp XXXXXXXXXX)

set -x  # FIXME
trap read debug  # FIXME

neural_style ${content} ${style} ${infile} 32
for resolution in 64 128 256
do
    multiresolution_step ${content} ${style} ${resolution} ${infile} ${outfile}
    cp ${outfile} ${infile}
done

cp ${outfile} ${output}

rm -f ${infile} ${outfile}
