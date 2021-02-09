# Overview

This repository contains the code for creating the API that will take inputs from the user and will return the prediction that trained in [CCAO's residential model](https://gitlab.com/ccao-data-science---modeling/models/ccao_res_avm).

# How it works

- `api_caller.R` contains the script to run local server. This is the entry point for the API, and will call the `api_generator.R`. This file also contains examples on how to call the API from R programming language.
- `api_generator.R` contains the script that process the inputs by making validation and return either the prediction value or the error message if the inputs are invalid.
- `lgbm_model.zip`, `lgbm_recipe.rds`, `postval_model.rds` are the files that used to prepare the inputs and create the predictions.

# Valid Inputs
This API accept the inputs in this [model explanation](https://gitlab.com/ccao-data-science---modeling/models/ccao_res_avm#features-used). The parameter naming and other details for each variables can be found in [CCAO package](https://gitlab.com/ccao-data-science---modeling/packages/ccao), you can run `ccao::vars_dict %>% filter(var_is_predictor == TRUE)`. 

  - Parameter name can be found in column `var_name_standard`.
  - Expected value/values for each parameter can be found in column `var_code`.
  - The explanation for each parameter can be found in column `var_name_pretty` and `var_notes`.

## Inputs Explanation
|Parameter Name|Inputs Code|Inputs Code Dict.|Description|
|----------------|-------------|-------------------|-------------|
|char_age ( Age )|Numeric|Numeric : Numeric||
|char_air ( Central Air Conditioning )|1, 2|1 : Central A/C, 2 : No Central A/C||
|char_apts ( Apartments )|1, 2, 3, 4, 5, 6|1 : Two, 2 : Three, 3 : Four, 4 : Five, 5 : Six, 6 : None||
|char_attic_fnsh ( Attic Finish )|1, 2, 3|1 : Living Area, 2 : Partial, 3 : None||
|char_attic_type ( Attic Type )|1, 2, 3|1 : Full, 2 : Partial, 3 : None||
|char_beds ( Bedrooms )|Numeric|Numeric : Numeric|Number of bedrooms in the property, defined based on building square footage and the judgement of the person in the field.|
|char_bldg_sf ( Building Square Feet )|Numeric|Numeric : Numeric|As measured from the exterior of the building.|
|char_bsmt ( Basement )|1, 2, 3, 4|1 : Full, 2 : Slab, 3 : Partial, 4 : Crawl||
|char_bsmt_fin ( Basement Finish )|1, 2, 3|1 : Formal Rec Room, 2 : Apartment, 3 : Unfinished||
|char_ext_wall ( Wall Material )|1, 2, 3, 4|1 : Frame, 2 : Masonry, 3 : Frame + Masonry, 4 : Stucco||
|char_fbath ( Full Baths )|Numeric|Numeric : Numeric|Number of full bathrooms, defined as having a bath or shower. If this value is missing, the default value is set to 1.|
|char_frpl ( Fireplaces )|Numeric|Numeric : Numeric|Number of fireplaces, counted as the number of flues one can see from the outside of the building.|
|char_gar1_area ( Garage 1 Area )|1, 2|1 : Yes, 2 : No|Is Garage 1 physically including within the building area? If yes, the garage area is subtracted from the building square feet calculation by the field agent.|
|char_gar1_att ( Garage 1 Attached )|1, 2|1 : Yes, 2 : No||
|char_gar1_cnst ( Garage 1 Material )|1, 2, 3, 4|1 : Frame, 2 : Masonry, 3 : Frame + Masonry, 4 : Stucco||
|char_gar1_size ( Garage 1 Size )|1, 2, 3, 4, 5, 6, 7, 8|1 : 1 cars, 2 : 1.5 cars, 3 : 2 cars, 4 : 2.5 cars, 5 : 3 cars, 6 : 3.5 cars, 7 : 0 cars, 8 : 4 cars||
|char_hbath ( Half Baths )|Numeric|Numeric : Numeric|Number of half baths, defined as bathrooms without a shower or bathtub.|
|char_hd_sf ( Land Square Feet )|Numeric|Numeric : Numeric|Square feet of the land (not just the building) of the property. Note that land is divided into 'plots' and 'parcels' - this field applies to parcels, identified by PIN.|
|char_heat ( Central Heating )|1, 2, 3, 4|1 : Warm Air Furnace, 2 : Hot Water Steam, 3 : Electric Heater, 4 : None||
|char_oheat ( Other Heating )|1, 2, 3, 4, 5|1 : Floor Furnace, 2 : Unit Heater, 3 : Stove, 4 : Solar, 5 : None||
|char_porch ( Porch )|1, 2, 3|1 : Frame Enclosed, 2 : Masonry Enclosed, 3 : None||
|char_roof_cnst ( Roof Material )|1, 2, 3, 4, 5, 6|1 : Shingle + Asphalt, 2 : Tar + Gravel, 3 : Slate, 4 : Shake, 5 : Tile, 6 : Other||
|char_rooms ( Rooms )|Numeric|Numeric : Numeric|Number of rooms in the property (excluding baths). Not to be confused with bedrooms|
|char_tp_dsgn ( Cathedral Ceiling )|1, 2|1 : Yes, 2 : No|This field name comes from a variable that is no longer used, but the field name was not changed to reflect Cathedral Ceiling|
|char_tp_plan ( Design Plan )|1, 2|1 : Architect, 2 : Stock Plan||
|char_type_resd ( Type of Residence )|1, 2, 3, 4, 5, 6, 7, 8, 9|1 : 1 Story, 2 : 2 Story, 3 : 3 Story +, 4 : Split Level, 5 : 1.5 Story, 6 : 1.6 Story, 7 : 1.7 Story, 8 : 1.8 Story, 9 : 1.9 Story|Residences with 1.5 - 1.9 stories are one story and have partial livable attics and are classified based on the square footage of the attic compared to the first floor of the house. So, 1.5 story houses have an attic that is 50% of the area of the first floor, 1.6 story houses are 60%, 1.7 are 70%, etc. However, what is recorded on the field card differs from what is in the database. All 1.5 - 1.9 story houses are coded as 5|
|char_use ( Use )|1, 2|1 : Single-Family, 2 : Multi-Family||
|econ_midincome ( Tract Median Income )|Numeric|Numeric : Numeric|Median income of the census tract containing the property centroid.|
|econ_tax_rate ( Tax Rate )|Numeric|Numeric : Numeric|Tax rate paid by the property owner. Taken from Cook County Treasurer's Office.|
|geo_floodplain ( FEMA Floodplain )|Logical|Logical : TRUE/FALSE|Indicator for whether property lies within a FEMA-defined floodplain.|
|geo_fs_flood_factor ( Flood Risk Factor )|Numeric|Numeric : Numeric|The property's First Street Flood Factor, a numeric integer from 1-10 (where 1 = minimal and 10 = extreme) based on flooding risk to the building footprint. Flood risk is defined as a combination of cumulative risk over 30 years and flood depth. Flood depth is calculated at the lowest elevation of the building footprint (largest if more than 1 exists, or property centroid where footprint does not exist. Data provided by First Street and academics at UPenn.|
|geo_fs_flood_risk_direction ( Flood Risk Direction )|Numeric|Numeric : Numeric|The property's flood risk direction represented in a numeric value based on the change in risk for the location from 2020 to 2050 for the climate model realization of the RCP 4.5 mid emissions scenario. -1 = descreasing, 0 = stationary, 1 = increasing. Data provided by First Street and academics at UPenn.|
|geo_ohare_noise ( O'Hare Noise Indicator )|Logical|Logical : TRUE/FALSE||
|geo_school_elem_district ( Elementary/Middle School District )|Numeric|Numeric : Numeric|Elementary and middle school district boundaries for Cook County and CPS.|
|geo_school_hs_district ( High School District )|Numeric|Numeric : Numeric|High school district boundaries for Cook County and CPS.|
|geo_withinmr100 ( Road Proximity < 100 Feet )|Logical|Logical : TRUE/FALSE|Indicates whether the property is within 100 feet of a major road.|
|geo_withinmr101300 ( Road Proximity 101 - 300 Feet )|Logical|Logical : TRUE/FALSE|Indicates whether the property is between 101 and 300 feet of a major road.|
|ind_garage ( Garage Indicator )|Logical|Logical : TRUE/FALSE|Indicates presence of a garage of any size.|
|ind_large_lot ( Large Lot Indicator )|Numeric|Numeric : Numeric|Large lot factor variable, where 1 acre of land (land square feet > 43559) is defined as a large lot. 1 = large lot, 0 = not a large lot.|
|meta_nbhd ( Neighborhood Code )|Numeric|Numeric : Numeric|Assessor neighborhood. First 2 digits are township code, last 3 digits are neighborhood code.|
|meta_sale_price ( Sale Price )|Numeric|Numeric : Numeric|Market price of sale.|
|meta_town_code ( Township Code )|Numeric|Numeric : Numeric||
|time_sale_day_of_year ( Sale Day of Year )|Numeric|Numeric : Numeric|Numeric encoding of day of year (1 - 365).|
|time_sale_during_holidays ( Sale During Holidays )|Logical|Logical : TRUE/FALSE|Indicator for whether sale occurred during holiday season (November - January).|
|time_sale_during_school_year ( Sale During School Year )|Logical|Logical : TRUE/FALSE|Indicator for whether sale occurred during usual school year (September - May).|
|time_sale_month_of_year ( Sale Month of Year )|Numeric|Numeric : Numeric|Character encoding of month of year (Jan - Dec).|
|time_sale_quarter ( Sale Quarter )|Numeric|Numeric : Numeric|Sale quarter calculated as the number of quarters since January 1997.|
|time_sale_quarter_of_year ( Sale Quarter of Year )|Numeric|Numeric : Numeric|Character encoding of quarter of year (Q1 - Q4).|
|time_sale_week ( Sale Week )|Numeric|Numeric : Numeric|Sale week calculated as the number of weeks since January 1st, 1997.|
|time_sale_week_of_year ( Sale Week of Year )|Numeric|Numeric : Numeric|Numeric encoding of week of year (1 - 52).|
|time_sale_year ( Sale Year )|Numeric|Numeric : Numeric|Sale year calculated as the number of years since 0 B.C.E.|
|meta_class|202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 234, 278, 295|202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 234, 278, 295||


# API Behavior
This API will return the prediction value if all inputs are valid, and return error message if not. Example of output when all input valid:

    {"initial_prediction":[382439.5081],"final_prediction":[382439.5081]}

The error message contains key-value pairs of invalid `variable_name` and `valid_options` for valid options. Example of error message when enter invalid value for parameter `char_air`:

    {"status":[false],"message":{"variable_name":["char_air"],"valid_options":["1, 2"]}}


# GET Request Example
    library(httr)

    url <- "http://localhost:8000/predict?char_age=112&char_air=2&char_apts=6&char_attic_fnsh=1&char_attic_type=2&char_beds=4&char_bldg_sf=2000&char_bsmt=1&char_bsmt_fin=3&char_ext_wall=1&char_fbath=2&char_frpl=1&char_gar1_area=2&char_gar1_att=2&char_gar1_cnst=1&char_gar1_size=3&char_hbath=0&char_hd_sf=12012&char_heat=1&char_oheat=5&char_porch=1&char_roof_cnst=1&char_rooms=7&char_tp_dsgn=2&char_tp_plan=2&char_type_resd=2&char_use=1&econ_midincome=148670&econ_tax_rate=7.216&geo_floodplain=0&geo_fs_flood_factor=1&geo_fs_flood_risk_direction=0&geo_ohare_noise=0&geo_school_elem_district=COMMUNITY%20UNIT%20SCHOOL%20DISTRICT%20220&geo_school_hs_district=COMMUNITY%20UNIT%20SCHOOL%20DISTRICT%20220&geo_withinmr100=0&geo_withinmr101300=0&ind_garage=TRUE&ind_large_home=FALSE&meta_nbhd=10012&meta_sale_price=307500&meta_town_code=10&time_sale_day_of_year=290&time_sale_during_holidays=FALSE&time_sale_during_school_year=TRUE&time_sale_month_of_year=10&time_sale_quarter_of_year=Q4&time_sale_week=1241&time_sale_week_of_year=42&ind_large_lot=1&time_sale_year=2&time_sale_quarter=2"

    r <- GET(url)
    print(content(r))
    
    
# POST Request Example
    samples <- arrow::read_parquet("samples.parquet")
    body <- toJSON(samples, pretty = TRUE)
    r <- POST(
        "http://localhost:8000/predict",
        httr::accept_json(),
        body = body
    )
    print(content(r))

    temp <- tibble(
        api_init = content(r)$initial_prediction,
        api_final = content(r)$final_prediction
    )