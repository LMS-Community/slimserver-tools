#!/bin/sh
./find_translations_todo.pl --dirs ~/git/server/ --product ueml
./find_translations_todo.pl --dirs ~/git/platforms/ --product ueml-platforms
./find_translations_todo.pl --dirs ~/git/network/docroot/ --product uesmartradio
./find_translations_todo.pl --dirs ~/git/squeezeplay/src/squeezeplay/ --product squeezeplay
./find_translations_todo.pl --dirs ~/git/squeezeplay/src/squeezeplay_squeezeos/ --product squeezeplay_squeezeos
./find_translations_todo.pl --dirs ~/git/squeezeplay/src/squeezeplay_baby/ --product squeezeplay_baby

mkdir ueml-osx
rsync -a --exclude=*.nib --include=**/*.strings ~/git/platforms/osx/Preference\ Pane/*.lproj ueml-osx

zip -r9 allstrings.zip ueml ueml-platforms uesmartradio squeezeplay squeezeplay_squeezeos squeezeplay_baby ueml-osx