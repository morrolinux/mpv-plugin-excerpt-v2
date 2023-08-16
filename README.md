# MPV-PLUGIN-EXCERPT-v2

This MPV plugin allows you to extract a portion of the video you're watching just by hitting "i" to set the IN point, "o" to set the OUT point and finally pressing "x" to export.

A new file with the same name prefix as the original will be generated in the same directory.

NB: This plugin suports multiple encoding profiles: ACCURATE (CPU encoding), ACCURATE (GPU encoding) and FAST (only muxing, no encoding). The FAST option will export your video segment in the blink of an eye. HOWEVER, it might not be as accurate of a cut as you wish. If you're aiming for frame-accurate cut, **make sure to use the ACCURATE modes with E.**

This fork of the [original project](https://github.com/lvml/mpv-plugin-excerpt) aims to provide a cleaner and bloat-free expirience. 

## Base requirements

- `ffmpeg` (mandatory)


## Requiraments for HW encoding using the GPU

- `pciutils` (needed for auto-selection of GPU encoder)
- `cuda` if you're using an NVIDIA GPU or
- `intel-vaapi-driver`, `intel-media-driver` or any other appropriate package depending on your model, if you're using an INTEL GPU. See [this page](https://wiki.archlinux.org/title/Hardware_video_acceleration) for more info.
