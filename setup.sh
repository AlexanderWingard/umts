#!/usr/bin/env sh

cd nitrogen
unlink rel/nitrogen/site
make rel_inets
mv rel/nitrogen/site/static/nitrogen site/static/nitrogen
rm -rf rel/nitrogen/site/
ln -s ../../../site rel/nitrogen