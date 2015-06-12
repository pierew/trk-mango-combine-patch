#!/bin/bash
read -p "Extracted TRK ISO Path (e.g. /home/paul/trk without 
ending Slash): " TRKPATH
cp ./* $TRKPATH/
rm -rf $TRKPATH/patch.sh
