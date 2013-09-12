# Basic jQuery plugin structure in CoffeeScript

NB: this is literate CoffeeScript.

 * source: http://bl.ocks.org/mbostock/4060606

## Installing

This has a few more dependencies to make work:

 * topojson
 * queue-async
 * underscore.js

But just use the bower file to reproduce.

### Preparing data

Preparing data is a complex deal, and requires some understanding of topojson
and its build process. TopoJSON itself isn't super scary, but the trick is
often getting GeoJSON out of whatever source data you have, and also knowing
what ESRI datums to use.

To help, I've included a Makefile with some examples, which successfully build
the sample data.

Along the way, there are several potential conversions that need to be made,
and all of these except for those resulting in TopoJSON may be performed using
the `ogr2ogr` tool, which is either a part of GDAL or PROJ4. Both of these are
easily installable via Homebrew or aptitude or yum, or if that fails, there's
someone out there who has made packages for various platforms.

 * shp -> kml
 * kml -> GeoJSON
 * shp -> GeoJSON
 * GeoJSON -> TopoJSON

### Further development

Building coffeescript with `coffee -bcm .` should be sufficient. See the
`package.json` file for dependencies.

## jQueryification

I'll explain how to initialize this a bit later.

    $.fn.extend

      d3choropleth: (options) ->
        self = $.fn.d3choropleth
        opts = $.extend {}, self.default_options, options

        $(this).each (i, el) ->
          self.init el, opts
          self.log el if opts.log

## Initialize plugin

This is where you set things so that the plugin may be called wth
`$("#selector").d3choropleth()`

* TODO: legend: http://bl.ocks.org/mbostock/5144735

I'll write about what all these things are, I swear, but just for now they're
enough to get the demo working.

    $.extend $.fn.d3choropleth,

      default_options:

Specify height and width of the div.

TODO: auto? + auto resize?

        height: 600
        width: 450

Debug

        log: true

Boundary definition info.

        boundary_json: "/d3choropleth/data/wards.topo.json"
        boundary_path: "wards.geo"
        boundary_label_property: "WARDS"
        boundary_id_field: "NAMEUPPER"

        # not in use - boundary_scale_by_property: false

        # ID of property to shade by
        boundary_shading_attribute: false
        boundary_class_name: "ward"
        boundary_label_class_name: "place-label"

        # shading_tsv: "/d3choropleth/data/ward_counts.tsv"
        # shading_tsv_id_field: "neighborhood"
        # shading_tsv_count_field: "rate"

        shading_tsv: false
        shading_tsv_id_field: false
        shading_tsv_count_field: false

Define the min and max to the quantization scale. Could do this automatically.

        quantization_min: 70
        quantization_max: 300
        quantization_class_name: "q"

When combining additional data sources in one topojson file, this is how to
access and display those sources.

        additional_data: false
        # [
        #  { datum_name: "lakes"
        #  , datum_element_container: "lakes"
        #  , datum_class_name: "lake"
        #  , datum_path: "water.geo"
        #  }
        # ]
      
      init: (el, opts) ->
        this.svg = this.createSvg el, opts
      
      createSvg: (el, opts) ->
        # This is going to be huge, so...
        self.svg = new Choropleth(el, opts)
        window.svg = self.svg
        if opts.logs
          console.log "initialized"
          console.log self.svg.opts
      
      log: (msg) ->
        console.log msg

# Choropleth class

    class Choropleth

We need a mapping so that we can later recall the data for each region.

      rateByID: d3.map()

      constructor: (@el, @opts) ->
        @makeSvg()

A helper function to construct bounds automatically based on width, height, and
the objects specified, from [here][http://bl.ocks.org/mbostock/5126418].

      make_bounds: (topo) ->
        width = @opts.width
        height = @opts.height
        b = @path.bounds(topo)
        s = .95 / Math.max((b[1][0] - b[0][0]) / width, (b[1][1] - b[0][1]) / height)
        t = [(width - s * (b[1][0] + b[0][0])) / 2, (height - s * (b[1][1] + b[0][1])) / 2]
        return [s, t]

This function initializes the projection and other mapping stuff, but then also
queues the requesting of external data.

      makeSvg: () ->

NB: before I was extracting some of the data here to populate a key <dl />.
Removing that for ease now. As long as the mapping is accessible somehow, this
can be done by another JavaScript function in the `$(document).ready` call.

        @proj = d3.geo.mercator()
                      .scale(1)
                      .translate([0, 0])

        @path = d3.geo.path().projection(@proj)

        q = queue().defer(d3.json, @opts.boundary_json)

If specifies a TSV data source for shading. 

        if @opts.shading_tsv
          q.defer(d3.tsv, @opts.shading_tsv, (d) =>
            _k = d[@opts.shading_tsv_id_field]
            _v = d[@opts.shading_tsv_count_field]
            @rateByID.set(_k, +_v)
          )

        q.await(@drawMap)

When this function is called, everything should be ready.

      drawMap: (error, json) =>

        boundary_path = @opts.boundary_path

        @topo = topojson.feature(
          json,
          json.objects[boundary_path]
        )

        @features = @topo.features

Readjust the scale based on the bounds of the objects present.

        [scale, translate] = @make_bounds(@topo)

        @proj.scale(scale)
             .translate(translate)

TODO: redraw on div size change?

        @svg = d3.select(@el).append("svg")
                .attr("preserveAspectRatio", "xMinYMin meet")
                # .call(d3.behavior.zoom().on("zoom", redraw))

        @json = json

Prepare the quantization scale.

        d_min = @opts.quantization_min
        d_max = @opts.quantization_max

        quanta = d3.scale.quantize()
                   .domain([d_min, d_max])
                   .range(d3.range(9).map( (i) => @opts.quantization_class_name + i + "-9" ))

If the user has defined an attribute to shade the boundary, collect all the
values into a mapping.

        if @opts.boundary_shading_attribute
          for d in @features
            @rateByID.set(d.id, d.properties[@opts.boundary_shading_attribute])
 
Define some class setters for inserting path elements.

        _prop_id = @opts.boundary_id_field

        _set_quantized_class = (d) =>
          _id_name = d.properties[_prop_id]
          "#{@opts.boundary_class_name} #{quanta(@rateByID.get(_id_name))}"

        _set_text_label_class = (d) =>
          _id_name = d.properties[_prop_id]
          "#{@opts.boundary_label_class_name} #{quanta(@rateByID.get(_id_name))}"

        _set_data_attribute_value = (d) =>
          d.properties[_prop_id]

        # Commenting some bits out for scaling by another property, just to
        # simplify a bit.

        # if @opts.boundary_scale_by_property
        #   _prop = @opts.boundary_scale_by_property
        #   populations = (d.properties[_prop] for d in @features)
        #   pop_max = _.max(populations)
        #   pop_sum = _.reduce(
        #     populations,
        #     ((memo, num) -> memo + num),
        #     0
        #   )

        #   _transform_string = (d) =>
        #     centroid = @path.centroid(d)
        #     pop = d.properties[_prop]
        #     [x, y] = centroid
        #     pop_frac = pop / pop_sum
        #     pop_calc = Math.sqrt(pop_frac * 5 || 0)
        #     """translate(#{x},#{y})scale(#{pop_calc})translate(#{-x},#{-y})"""
          
        # if @opts.boundary_scale_by_property
        #   @svg.selectAll("path")
        #       .data(@features)
        #       .enter().append("path")
        #       .attr("class", _set_quantized_class)
        #       .attr("data-#{@opts.boundary_class_name}", _set_data_attribute_value)
        #       .attr("transform", _transform_string) # This
        #       .attr("d", @path)
        # else

This defines how the regions are shaded, sets a quantized classname, as well as
includes the actual data as an attribute.

        @svg.selectAll("path")
            .data(@features)
            .enter().append("path")
            .attr("class", _set_quantized_class)
            .attr("data-#{@opts.boundary_class_name}", _set_data_attribute_value)
            .attr("d", @path)

        @svg.selectAll(".#{@opts.boundary_class_name}-border")
          .data(@features)
          .enter().append("path")
          .attr("class", "#{@opts.boundary_class_name}-border" )
          .attr("data-#{@opts.boundary_class_name}", _set_data_attribute_value)
          .attr("d", @path)

Now we draw place labels. They need to be translated to the center of the
geometry. Then, text ndoes are appended with the relevant classes.

        _transform_to_centroid_geom = (d) =>
          "translate(#{@path.centroid(d.geometry)})"

        @svg.selectAll(".place-label")
            .data(@features)
            .enter()
            .append("text")
            .attr("class", _set_text_label_class)
            .attr("transform", _transform_to_centroid_geom)
            .attr("dy", ".35em")
            .style("text-anchor", "middle")
            .text((d) => d.properties[@opts.boundary_label_property])

        if @opts.additional_data
          @add_additional_datasources(error, json)

If any additional sources are defined for data, iterate and draw them all.

      add_additional_datasources: (error, json) =>
        for source in @opts.additional_data
          json_objs = json.objects[source.datum_path]
          @svg.selectAll(source.datum_element_container)
              .data(topojson.feature(json, json_objs).features)
              .enter().append("path")
              .attr("class", source.datum_class_name)
              .attr("d", @path)

    # vim: set ts=4 sw=4 tw=0 syntax=litcoffee :
