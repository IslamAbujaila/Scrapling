#!/usr/bin/env bash
# Builds the Rokana night promo from the night still (rokana-night-keyframe.png) using ffmpeg only.
set -euo pipefail
cd "$(dirname "$0")"
W=3840; H=2160; FPS=30
# 16:9 crop of the still, 4x supersampled so the slow camera moves stay smooth
SRC="crop=2728:1536:12:0,scale=10912:6144:flags=lanczos"
shot() { # name frames zoom_expr cx_expr cy_expr   (cx/cy in still pixels)
  ffmpeg -v error -y -loop 1 -i rokana-night-keyframe.png -vf "$SRC,zoompan=z='$3':x='($4)*4-iw/zoom/2':y='($5)*4-ih/zoom/2':d=$2:s=${W}x${H}:fps=$FPS" \
    -frames:v "$2" -c:v libx264 -preset veryfast -crf 12 -pix_fmt yuv420p "work/$1.mp4"
}
# 1) wide establishing shot, slow push-in
shot s1 165 '1.0+0.16*on/164' '1364' '768+40*on/164' &
# 2) closer push toward the entrance, tilting up to the sign
shot s2 150 '1.38+0.30*on/149' '1300' '930-200*on/149' &
wait
# 3) final wide shot, easing out to the full building
shot s3 165 '1.16-0.16*(1-pow(1-on/164,2))' '1364' '790-22*(1-pow(1-on/164,2))'
# join with soft dissolves, then bloom, vignette, grain, fades
ffmpeg -v error -y -i work/s1.mp4 -i work/s2.mp4 -i work/s3.mp4 -filter_complex "
[0][1]xfade=transition=fade:duration=0.6:offset=4.9[a];
[a][2]xfade=transition=fade:duration=0.6:offset=9.3[b];
[b]split[m][g];[g]lutrgb=r='clip((val-150)*2.4,0,255)':g='clip((val-150)*2.4,0,255)':b='clip((val-150)*2.4,0,255)',gblur=sigma=30[gb];
[m][gb]blend=all_mode=screen:all_opacity=0.30,
vignette=PI/8,noise=alls=3:allf=t,
fade=t=in:st=0:d=1.2,fade=t=out:st=13.8:d=1,format=yuv420p[v]" \
  -map "[v]" -c:v libx264 -preset slow -crf 22 -movflags +faststart rokana-night-promo-4k.mp4
ffmpeg -v error -y -i rokana-night-promo-4k.mp4 -vf scale=1920:1080:flags=lanczos -c:v libx264 -preset slow -crf 19 -movflags +faststart rokana-night-promo-1080p.mp4
