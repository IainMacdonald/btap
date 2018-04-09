require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'fileutils'
require 'openstudio-standards'
begin
  require 'openstudio_measure_tester/test_helper'
rescue LoadError
  puts 'OpenStudio Measure Tester Gem not installed -- will not be able to aggregate and dashboard the results of tests'
end
require_relative '../measure.rb'
require 'minitest/autorun'


class BTAPEnvelopeConstructionMeasure_Test < Minitest::Test
  def test_create_building()
    @surface_index =[
        {"boundary_condition" => "Outdoors",  "construction_type" => "opaque", "surface_type" => "Wall"},
        {"boundary_condition" => "Outdoors",  "construction_type" => "opaque", "surface_type" => "RoofCeiling"},
        {"boundary_condition" => "Outdoors",  "construction_type" => "opaque", "surface_type" => "Floor"},
        {"boundary_condition" => "Ground",    "construction_type" => "opaque", "surface_type" => "Wall"},
        {"boundary_condition" => "Ground",    "construction_type" => "opaque", "surface_type" => "RoofCeiling"},
        {"boundary_condition" => "Ground",    "construction_type" => "opaque", "surface_type" => "Floor"}
    ]

    @sub_surface_index = [
        {"boundary_condition" => "Outdoors", "construction_type" => "glazing",  "surface_type" => "FixedWindow"},
        {"boundary_condition" => "Outdoors", "construction_type" => "glazing",  "surface_type" => "OperableWindow"},
        {"boundary_condition" => "Outdoors", "construction_type" => "glazing",  "surface_type" => "Skylight"},
        {"boundary_condition" => "Outdoors", "construction_type" => "glazing",  "surface_type" => "TubularDaylightDiffuser"},
        {"boundary_condition" => "Outdoors", "construction_type" => "glazing",  "surface_type" => "TubularDaylightDome"},
        {"boundary_condition" => "Outdoors", "construction_type" => "opaque",   "surface_type" => "Door"},
        {"boundary_condition" => "Outdoors", "construction_type" => "glazing",  "surface_type" => "GlassDoor"},
        {"boundary_condition" => "Outdoors", "construction_type" => "opaque",   "surface_type" => "OverheadDoor"}
    ]




    # Create an instance of the measure
    measure = BTAPEnvelopeConstructionMeasure.new

    # Create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)


    # Use the NECB prototype to create a model to test against. Alterantively we could load an osm file instead.
    model = create_model("FullServiceRestaurant",
                         'NECB HDD Method',
                         'CAN_BC_Vancouver.Intl.AP.718920_CWEC2016.epw',
                         "NECB2011")




    # Test arguments and defaults
    arguments = measure.arguments(model)
    #check number of arguments.
    assert_equal(26, arguments.size)

    (@surface_index + @sub_surface_index).each_with_index do |surface,index|
      ecm_name = "ecm_#{surface['boundary_condition'].downcase}_#{surface['surface_type'].downcase}_conductance"
      assert_equal(ecm_name, arguments[index].name)
      assert_equal('baseline', arguments[index].defaultValueAsString)
    end

    # set argument values to values and run the measure
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)


    #Set up conductance test values to validate against. Make each unique to make each surface type distinct.
    values = {}
    conductance = 3.5
    (@surface_index + @sub_surface_index).each_with_index do |surface,index|
      ecm_name = "ecm_#{surface['boundary_condition'].downcase}_#{surface['surface_type'].downcase}_conductance"
      argument = arguments[index].clone
      assert(argument.setValue(conductance.to_s))
      argument_map[ecm_name] = argument
      values[ecm_name] =conductance
    end

    conductance_argument_size = (@surface_index + @sub_surface_index).size
    #SHGC
    shgc = 0.999
    @sub_surface_index.select {|surface| surface['construction_type'] == "glazing"}.each_with_index do |surface,index|
      ecm_name = "ecm_#{surface['boundary_condition'].downcase}_#{surface['surface_type'].downcase}_shgc"
      argument = arguments[conductance_argument_size + index].clone
      assert(argument.setValue(shgc.to_s))
      argument_map[ecm_name] = argument
      values[ecm_name] =shgc
    end

    #SHGC
    shgc_argument_size = @sub_surface_index.select {|surface| surface['construction_type'] == "glazing"}.size
    tvis = 0.999
    @sub_surface_index.select {|surface| surface['construction_type'] == "glazing"}.each_with_index do |surface,index|
      ecm_name = "ecm_#{surface['boundary_condition'].downcase}_#{surface['surface_type'].downcase}_tvis"
      argument = arguments[conductance_argument_size + shgc_argument_size + index].clone
      assert(argument.setValue(tvis.to_s))
      argument_map[ecm_name] = argument
      values[ecm_name] =tvis
    end

    #run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    assert(result.value.valueName == 'Success')
    #Check that the conductances have indeed changed to what they should be.
    outdoor_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(model.getSurfaces(), "Outdoors")
    outdoor_subsurfaces = BTAP::Geometry::Surfaces::get_subsurfaces_from_surfaces(outdoor_surfaces)
    ground_surfaces = BTAP::Geometry::Surfaces::filter_by_boundary_condition(model.getSurfaces(), "Ground")

    ext_windows = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["FixedWindow", "OperableWindow"])
    ext_skylights = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["Skylight", "TubularDaylightDiffuser", "TubularDaylightDome"])
    ext_doors = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["Door", "GlassDoor"])
    ext_glass_doors = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["GlassDoor"])
    ext_overhead_doors = BTAP::Geometry::Surfaces::filter_subsurfaces_by_types(outdoor_subsurfaces, ["OverheadDoor"])

    #opaque surfaces
    (outdoor_surfaces + ext_doors +ext_overhead_doors).each do |surface|
      ecm_name = "ecm_#{surface.outsideBoundaryCondition.downcase}_#{surface.surfaceType.downcase}_conductance"
      assert_equal(values[ecm_name].to_f.round(3), BTAP::Geometry::Surfaces::get_surface_construction_conductance(surface).round(3)) unless values[ecm_name] == @baseline
    end

    #glazing subsurfaces
    (ext_windows + ext_glass_doors +ext_skylights).each do |surface|
      ecm_cond_name = "ecm_#{surface.outsideBoundaryCondition.downcase}_#{surface.subSurfaceType.downcase}_conductance"
      ecm_shgc_name = "ecm_#{surface.outsideBoundaryCondition.downcase}_#{surface.subSurfaceType.downcase}_shgc"
      ecm_tvis_name = "ecm_#{surface.outsideBoundaryCondition.downcase}_#{surface.subSurfaceType.downcase}_tvis"
      assert_equal(values[ecm_cond_name].to_f.round(3), BTAP::Geometry::Surfaces::get_surface_construction_conductance(surface).round(3)) unless values[ecm_cond_name] == @baseline
      construction = OpenStudio::Model::getConstructionByName(surface.model, surface.construction.get.name.to_s).get
      assert_equal(values[ecm_shgc_name].to_f.round(3), construction.layers.first.to_SimpleGlazing.get.getSolarHeatGainCoefficient.value.round(3)) unless values[ecm_shgc_name] == @baseline
      construction = OpenStudio::Model::getConstructionByName(surface.model, surface.construction.get.name.to_s).get
      error_message = "Setting TVis for #{construction.name} to #{values[ecm_tvis_name].to_f.round(3)} failed. Actual is #{construction.layers.first.to_SimpleGlazing.get.getVisibleTransmittance.get.value}"
      assert_equal(values[ecm_tvis_name].to_f.round(3), construction.layers.first.to_SimpleGlazing.get.getVisibleTransmittance.get.value.round(3), error_message) unless values[ecm_tvis_name] == @baseline
    end
  end

  def copy_model(model)
    copy_model = OpenStudio::Model::Model.new
    # remove existing objects from model
    handles = OpenStudio::UUIDVector.new
    copy_model.objects.each do |obj|
      handles << obj.handle
    end
    copy_model.removeObjects(handles)
    # put contents of new_model into model_to_replace
    copy_model.addObjects(model.toIdfFile.objects)
    return copy_model
  end

  def create_model(building_type, climate_zone, epw_file, template)
    osm_directory = "#{Dir.pwd}/output/#{building_type}-#{template}-#{climate_zone}-#{epw_file}"
    Dir.mkdir(osm_directory) unless Dir.exists?(osm_directory)
    #Get Weather climate zone from lookup
    weather = BTAP::Environment::WeatherFile.new(epw_file)
    #create model
    building_name = "#{template}_#{building_type}"
    puts "Creating #{building_name}"
    prototype_creator = Standard.build(building_name)
    model = prototype_creator.model_create_prototype_model(climate_zone,
                                                           epw_file,
                                                           osm_directory,
                                                           @debug,
                                                           model)
    #set weather file to epw_file passed to model.
    weather.set_weather_file(model)
    return model
  end


end
