# style-swap-docker

A dockerized version of the [style-swap algorithm by rtqichen](https://github.com/rtqichen/style-swap). [nvidia-docker](https://github.com/NVIDIA/nvidia-docker) is used to make use of GPU hardware.

THIS IS WORK IN PROGRESSS

## Maximum genertion sizes

* P100: content size 1300 with decoder network

## TODOs

* Add decoder network inside the container
* In [Painnt](http://moonlighting.io/painnt-browse-effects?effid=524) multiscale generation seems to be taking place, with large patterns appearning in the background while keeping the structure and fine details.

## References

* [A review on style transfer methods](https://arxiv.org/pdf/1705.04058.pdf)
* Fast Patch-based Style Transfer of Arbitrary Style: [paper](https://arxiv.org/pdf/1612.04337.pdf), [implementation](https://github.com/rtqichen/style-swap)

