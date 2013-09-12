# jQuery Choropleth

A simple package based on some recipes by `@mbostock`, chiefly the one
following, to allow for easy and quick creation of choropleth maps by ESRI
Shapefiles and TSVs. I thought I'd make a jQuery plugin to make developing a
project of mine easier, and so far it has been... However, I've got some
documentation to write...

 * source: http://bl.ocks.org/mbostock/4060606

An additional goal is documenting the build process in a Makefile and tracking
down common difficulties in creating these kinds of data representations. If
you encounter some more problems, open an issue!

## Features

 * Autoscale, and translate to the data.
 * Load from TSV, or from a field in the topojson files.
 * Maybe more, which I'll document when the time comes...

## Caveats

 * This is pretty specific to the projection I'm working with, but maybe I'll
   fix that.
 * No auto-resize events for responsive stuff
 * Probably more... ;)

## Included Sample

 * The sample provided here includes random data for Minneapolis neighborhoods,
   as well as a link to the shapefiles.

## Testing

To test with the sample data, `make` should be sufficient. Then try running an
HTTP server (`python -m SimpleHTTPServer`) and browse to the file. If you don't
see anything, check the output of `make`, or inspect the error console. There
*could* be browser-specific issues that I haven't worked out yet. If so, drop
me a line.
