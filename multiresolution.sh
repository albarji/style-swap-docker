#!/usr/bin/env bash

# Generates an image incrementally, so as to produce multiscale resolution effects
#
# $1: content
# $2: style
# $3: output

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
    mv $outdir/*_stylized.* $3
    rm -rf $indir
}

#out2=$(mktemp XXXXXXXXXX.png)
#neural_style $1 $2 ${out2} 64
#out3=$(mktemp XXXXXXXXXX.png)
#neural_style ${out2} $2 ${out3} 128
out4=$(mktemp XXXXXXXXXX.png)
#neural_style ${out3} $2 ${out4} 256
neural_style $1 $2 ${out4} 256
neural_style ${out4} $2 $3 512

# TODO: if we just reiterate the transformed image, quality will be poor. We need to somehow merge both the original
# image and the one from the previous iteration